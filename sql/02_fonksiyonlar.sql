-- ============================================================
-- BLM4522 — Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma
-- BÖLÜM 2: YARDIMCI FONKSİYONLAR
-- ============================================================

-- 2.1 Strateji id'sini isme göre döndür
CREATE OR REPLACE FUNCTION recovery_mgmt.get_strategy_id(p_name VARCHAR)
RETURNS INT LANGUAGE plpgsql AS $$
DECLARE v_id INT;
BEGIN
    SELECT strategy_id INTO v_id
    FROM recovery_mgmt.backup_strategy
    WHERE strategy_name = p_name AND is_active = TRUE;

    IF v_id IS NULL THEN
        RAISE EXCEPTION 'Strateji bulunamadi: %', p_name;
    END IF;
    RETURN v_id;
END;
$$;

-- 2.2 Yedek kaydı aç ve record_id döndür
CREATE OR REPLACE FUNCTION recovery_mgmt.open_backup_record(
    p_type      VARCHAR,
    p_db        VARCHAR,
    p_path      TEXT,
    p_parent_id INT DEFAULT NULL
)
RETURNS INT LANGUAGE plpgsql AS $$
DECLARE
    v_id       INT;
    v_strat_id INT;
BEGIN
    v_strat_id := recovery_mgmt.get_strategy_id(p_type);

    INSERT INTO recovery_mgmt.backup_record
        (strategy_id, backup_type, parent_full_id, db_name, backup_path, status)
    VALUES
        (v_strat_id, p_type, p_parent_id, p_db, p_path, 'RUNNING')
    RETURNING record_id INTO v_id;

    RETURN v_id;
END;
$$;

-- 2.3 Northwind'in 5 ana tablosunun satır sayısını snapshot'a kaydet
--     Doğrulama testlerinde baz alınır
CREATE OR REPLACE FUNCTION recovery_mgmt.take_row_snapshot(p_record_id INT)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO recovery_mgmt.row_count_snapshot (record_id, table_name, row_count)
    SELECT p_record_id, 'customers',     COUNT(*) FROM public.customers   UNION ALL
    SELECT p_record_id, 'orders',        COUNT(*) FROM public.orders      UNION ALL
    SELECT p_record_id, 'order_details', COUNT(*) FROM public.order_details UNION ALL
    SELECT p_record_id, 'products',      COUNT(*) FROM public.products    UNION ALL
    SELECT p_record_id, 'suppliers',     COUNT(*) FROM public.suppliers;
END;
$$;
