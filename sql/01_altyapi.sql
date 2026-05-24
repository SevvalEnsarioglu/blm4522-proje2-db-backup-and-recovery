-- ============================================================
-- BLM4522 — Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma
-- BÖLÜM 1: ALTYAPI — Şema, Tablolar ve Yedekleme Stratejileri
-- Veritabanı: Northwind | Platform: PostgreSQL + DBeaver
-- ============================================================

-- Şema oluştur
CREATE SCHEMA IF NOT EXISTS recovery_mgmt;

-- 1.1 Yedekleme stratejisi tanımları: FULL / INCREMENTAL / DIFFERENTIAL
CREATE TABLE IF NOT EXISTS recovery_mgmt.backup_strategy (
    strategy_id     SERIAL PRIMARY KEY,
    strategy_name   VARCHAR(50) NOT NULL,  -- 'FULL' | 'INCREMENTAL' | 'DIFFERENTIAL'
    description     TEXT,
    frequency_hours INT         NOT NULL,  -- kaç saatte bir alınır
    retention_days  INT         NOT NULL,  -- kaç gün saklanır
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE
);

-- 1.2 Her yedekleme işleminin log kaydı
CREATE TABLE IF NOT EXISTS recovery_mgmt.backup_record (
    record_id       SERIAL PRIMARY KEY,
    strategy_id     INT REFERENCES recovery_mgmt.backup_strategy(strategy_id),
    backup_type     VARCHAR(20)  NOT NULL,
    parent_full_id  INT,                    -- ARTIK/FARK için üst FULL yedek id'si
    db_name         VARCHAR(100) NOT NULL,
    backup_path     TEXT         NOT NULL,
    started_at      TIMESTAMP    NOT NULL DEFAULT NOW(),
    finished_at     TIMESTAMP,
    status          VARCHAR(20)  NOT NULL DEFAULT 'RUNNING',
    row_count_snap  BIGINT,                 -- yedek anındaki satır sayısı
    file_size_bytes BIGINT,
    checksum        TEXT,                   -- MD5 doğrulama hash'i
    error_message   TEXT
);

-- 1.3 Felaket senaryosu ve kurtarma kayıtları
CREATE TABLE IF NOT EXISTS recovery_mgmt.disaster_scenario (
    scenario_id     SERIAL PRIMARY KEY,
    scenario_type   VARCHAR(50) NOT NULL,  -- 'ACCIDENTAL_DELETE' | 'DROP_TABLE' | 'CORRUPTION'
    affected_table  VARCHAR(100),
    affected_rows   INT,
    simulated_at    TIMESTAMP   NOT NULL DEFAULT NOW(),
    recovery_done   TIMESTAMP,
    recovery_status VARCHAR(20) DEFAULT 'PENDING',
    notes           TEXT
);

-- 1.4 Yedek doğrulama test sonuçları
CREATE TABLE IF NOT EXISTS recovery_mgmt.backup_verification (
    verify_id      SERIAL PRIMARY KEY,
    record_id      INT REFERENCES recovery_mgmt.backup_record(record_id),
    verified_at    TIMESTAMP   NOT NULL DEFAULT NOW(),
    test_type      VARCHAR(50) NOT NULL,  -- 'ROW_COUNT' | 'CHECKSUM' | 'RESTORE_TEST'
    expected_value TEXT,
    actual_value   TEXT,
    result         VARCHAR(20) NOT NULL   -- 'PASS' | 'FAIL'
);

-- 1.5 Point-in-time kurtarma kayıtları
CREATE TABLE IF NOT EXISTS recovery_mgmt.pitr_log (
    pitr_id        SERIAL PRIMARY KEY,
    target_time    TIMESTAMP   NOT NULL,
    used_backup_id INT REFERENCES recovery_mgmt.backup_record(record_id),
    recovery_table VARCHAR(100),
    rows_recovered INT,
    started_at     TIMESTAMP   NOT NULL DEFAULT NOW(),
    finished_at    TIMESTAMP,
    status         VARCHAR(20) NOT NULL DEFAULT 'RUNNING'
);

-- 1.6 Doğrulama için satır sayısı snapshot tablosu
CREATE TABLE IF NOT EXISTS recovery_mgmt.row_count_snapshot (
    snap_id    SERIAL PRIMARY KEY,
    record_id  INT REFERENCES recovery_mgmt.backup_record(record_id),
    table_name VARCHAR(100) NOT NULL,
    row_count  BIGINT       NOT NULL,
    snapped_at TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- ============================================================
-- Yedekleme stratejilerini ekle
-- ============================================================
INSERT INTO recovery_mgmt.backup_strategy
    (strategy_name, description, frequency_hours, retention_days)
VALUES
    ('FULL',
     'Tum veritabaninin eksiksiz yedegi. Diger tiplerin referans noktasidir.',
     168, 30),   -- haftada 1, 30 gun sakla

    ('INCREMENTAL',
     'Son yedekten bu yana degisen satirlarin yedegi. Kucuk boyut, hizli alinir.',
     6, 7),      -- 6 saatte 1, 7 gun sakla

    ('DIFFERENTIAL',
     'Son FULL yedekten bu yana degisen tum verilerin yedegi.',
     24, 14)     -- gunluk, 14 gun sakla

ON CONFLICT DO NOTHING;

-- Strateji tablosunu dogrula
SELECT strategy_name, frequency_hours, retention_days FROM recovery_mgmt.backup_strategy;
