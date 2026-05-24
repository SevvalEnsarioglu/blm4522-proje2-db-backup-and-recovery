-- ============================================================
-- BLM4522 — Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma
-- BÖLÜM 3: TAM (FULL) YEDEKLEME
-- ============================================================
-- TAM yedek: tüm veritabanını pg_dump ile yedekler.
-- ARTIK ve FARK yedeklerin referans noktasıdır.
-- ============================================================

CREATE OR REPLACE FUNCTION recovery_mgmt.take_full_backup(
    p_db VARCHAR DEFAULT 'northwind'
)
RETURNS TABLE (record_id INT, status VARCHAR, backup_path TEXT, message TEXT)
LANGUAGE plpgsql AS $$
DECLARE
    v_path      TEXT;
    v_cmd       TEXT;
    v_record_id INT;
BEGIN
    -- Dosya: /tmp/dr_backups/northwind_FULL_20250524_020000.dump
    v_path      := '/tmp/dr_backups/' || p_db
                   || '_FULL_' || TO_CHAR(NOW(), 'YYYYMMDD_HH24MISS') || '.dump';
    v_record_id := recovery_mgmt.open_backup_record('FULL', p_db, v_path);

    -- Yedek anındaki satır sayılarını kaydet (doğrulama için)
    PERFORM recovery_mgmt.take_row_snapshot(v_record_id);

    BEGIN
        -- pg_dump custom format (-Fc): sıkıştırılmış, pg_restore uyumlu
        v_cmd := 'pg_dump -U postgres -Fc -d ' || p_db || ' -f ' || v_path;
        EXECUTE format('COPY (SELECT 1) TO PROGRAM %L', v_cmd);

        UPDATE recovery_mgmt.backup_record
        SET finished_at = NOW(), status = 'SUCCESS'
        WHERE record_id = v_record_id;

        RAISE NOTICE '[FULL BACKUP] Basarili → %', v_path;
        RETURN QUERY SELECT v_record_id, 'SUCCESS'::VARCHAR,
                            v_path, 'Tam yedek basariyla alindi.'::TEXT;

    EXCEPTION WHEN OTHERS THEN
        UPDATE recovery_mgmt.backup_record
        SET finished_at = NOW(), status = 'FAILED', error_message = SQLERRM
        WHERE record_id = v_record_id;

        RAISE WARNING '[FULL BACKUP] BASARISIZ: %', SQLERRM;
        RETURN QUERY SELECT v_record_id, 'FAILED'::VARCHAR,
                            v_path, ('Hata: ' || SQLERRM)::TEXT;
    END;
END;
$$;

-- Test: Tam yedek al
-- SELECT * FROM recovery_mgmt.take_full_backup();
