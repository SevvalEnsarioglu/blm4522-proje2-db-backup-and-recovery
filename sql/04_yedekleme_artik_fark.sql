-- ============================================================
-- BLM4522 — Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma
-- BÖLÜM 4: ARTIK (INCREMENTAL) ve FARK (DIFFERENTIAL) YEDEKLEME
-- ============================================================

-- ============================================================
-- Staging tabloları: değişen satırların JSON kopyaları
-- ============================================================

-- ARTIK yedek için staging (son yedekten bu yana değişenler)
CREATE TABLE IF NOT EXISTS recovery_mgmt.incremental_staging (
    staging_id   SERIAL PRIMARY KEY,
    record_id    INT REFERENCES recovery_mgmt.backup_record(record_id),
    source_table VARCHAR(100) NOT NULL,
    row_data     JSONB        NOT NULL,
    captured_at  TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- FARK yedek için staging (son FULL'dan bu yana değişenlerin tamamı)
CREATE TABLE IF NOT EXISTS recovery_mgmt.differential_staging (
    staging_id   SERIAL PRIMARY KEY,
    record_id    INT REFERENCES recovery_mgmt.backup_record(record_id),
    source_table VARCHAR(100) NOT NULL,
    row_data     JSONB        NOT NULL,
    captured_at  TIMESTAMP    NOT NULL DEFAULT NOW()
);


-- ============================================================
-- ARTIK (INCREMENTAL) yedek fonksiyonu
-- Son FULL yedekten sonra gelen orders satırlarını yakalar
-- Kurtarmada tüm zincir gerekir: FULL → INC1 → INC2 → ...
-- ============================================================
CREATE OR REPLACE FUNCTION recovery_mgmt.take_incremental_backup(
    p_full_record_id INT,
    p_db             VARCHAR DEFAULT 'northwind'
)
RETURNS TABLE (record_id INT, status VARCHAR, captured_rows BIGINT, message TEXT)
LANGUAGE plpgsql AS $$
DECLARE
    v_path        TEXT;
    v_record_id   INT;
    v_last_time   TIMESTAMP;
    v_captured    BIGINT;
BEGIN
    SELECT started_at INTO v_last_time
    FROM recovery_mgmt.backup_record
    WHERE record_id = p_full_record_id;

    IF v_last_time IS NULL THEN
        RAISE EXCEPTION 'Gecersiz FULL record_id: %', p_full_record_id;
    END IF;

    v_path      := '/tmp/dr_backups/' || p_db
                   || '_INC_' || TO_CHAR(NOW(), 'YYYYMMDD_HH24MISS') || '.json';
    v_record_id := recovery_mgmt.open_backup_record(
                       'INCREMENTAL', p_db, v_path, p_full_record_id);

    BEGIN
        -- Son yedekten bu yana gelen orders satırlarını JSON olarak sakla
        INSERT INTO recovery_mgmt.incremental_staging (record_id, source_table, row_data)
        SELECT v_record_id, 'orders', row_to_json(o.*)::JSONB
        FROM public.orders o
        WHERE o.order_date >= v_last_time OR o.shipped_date >= v_last_time;

        GET DIAGNOSTICS v_captured = ROW_COUNT;
        PERFORM recovery_mgmt.take_row_snapshot(v_record_id);

        UPDATE recovery_mgmt.backup_record
        SET finished_at = NOW(), status = 'SUCCESS', row_count_snap = v_captured
        WHERE record_id = v_record_id;

        RAISE NOTICE '[INCREMENTAL] % satir yakalandi → %', v_captured, v_path;
        RETURN QUERY SELECT v_record_id, 'SUCCESS'::VARCHAR,
                            v_captured, 'Artik yedek basarili.'::TEXT;

    EXCEPTION WHEN OTHERS THEN
        UPDATE recovery_mgmt.backup_record
        SET finished_at = NOW(), status = 'FAILED', error_message = SQLERRM
        WHERE record_id = v_record_id;
        RETURN QUERY SELECT v_record_id, 'FAILED'::VARCHAR,
                            0::BIGINT, ('Hata: ' || SQLERRM)::TEXT;
    END;
END;
$$;


-- ============================================================
-- FARK (DIFFERENTIAL) yedek fonksiyonu
-- Son FULL'dan bu yana değişen TÜM orders + order_details satırları
-- ARTIK'tan büyük ama kurtarma daha hızlı: sadece FULL + son DIFF gerekir
-- ============================================================
CREATE OR REPLACE FUNCTION recovery_mgmt.take_differential_backup(
    p_full_record_id INT,
    p_db             VARCHAR DEFAULT 'northwind'
)
RETURNS TABLE (record_id INT, status VARCHAR, captured_rows BIGINT, message TEXT)
LANGUAGE plpgsql AS $$
DECLARE
    v_path      TEXT;
    v_record_id INT;
    v_full_time TIMESTAMP;
    v_captured  BIGINT := 0;
    v_cnt       BIGINT;
BEGIN
    SELECT started_at INTO v_full_time
    FROM recovery_mgmt.backup_record
    WHERE record_id = p_full_record_id AND backup_type = 'FULL';

    IF v_full_time IS NULL THEN
        RAISE EXCEPTION 'Gecersiz FULL record_id: %', p_full_record_id;
    END IF;

    v_path      := '/tmp/dr_backups/' || p_db
                   || '_DIFF_' || TO_CHAR(NOW(), 'YYYYMMDD_HH24MISS') || '.json';
    v_record_id := recovery_mgmt.open_backup_record(
                       'DIFFERENTIAL', p_db, v_path, p_full_record_id);

    BEGIN
        -- orders: son FULL'dan bu yana tüm değişiklikler
        INSERT INTO recovery_mgmt.differential_staging (record_id, source_table, row_data)
        SELECT v_record_id, 'orders', row_to_json(o.*)::JSONB
        FROM public.orders o WHERE o.order_date >= v_full_time;
        GET DIAGNOSTICS v_cnt = ROW_COUNT;
        v_captured := v_captured + v_cnt;

        -- order_details: ilgili siparişlerin detayları
        INSERT INTO recovery_mgmt.differential_staging (record_id, source_table, row_data)
        SELECT v_record_id, 'order_details', row_to_json(od.*)::JSONB
        FROM public.order_details od
        JOIN public.orders o ON od.order_id = o.order_id
        WHERE o.order_date >= v_full_time;
        GET DIAGNOSTICS v_cnt = ROW_COUNT;
        v_captured := v_captured + v_cnt;

        PERFORM recovery_mgmt.take_row_snapshot(v_record_id);

        UPDATE recovery_mgmt.backup_record
        SET finished_at = NOW(), status = 'SUCCESS', row_count_snap = v_captured
        WHERE record_id = v_record_id;

        RAISE NOTICE '[DIFFERENTIAL] % satir yakalandi → %', v_captured, v_path;
        RETURN QUERY SELECT v_record_id, 'SUCCESS'::VARCHAR,
                            v_captured, 'Fark yedegi basarili.'::TEXT;

    EXCEPTION WHEN OTHERS THEN
        UPDATE recovery_mgmt.backup_record
        SET finished_at = NOW(), status = 'FAILED', error_message = SQLERRM
        WHERE record_id = v_record_id;
        RETURN QUERY SELECT v_record_id, 'FAILED'::VARCHAR,
                            0::BIGINT, ('Hata: ' || SQLERRM)::TEXT;
    END;
END;
$$;
