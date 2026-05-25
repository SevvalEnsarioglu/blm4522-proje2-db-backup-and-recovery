-- 1. BACKUP ŞEMASI OLUŞTURMA
CREATE SCHEMA IF NOT EXISTS backup_dr;

DROP TABLE IF EXISTS backup_dr.backup_history CASCADE;
DROP TABLE IF EXISTS backup_dr.recovery_points CASCADE;
DROP TABLE IF EXISTS backup_dr.products_full_backup CASCADE;
DROP TABLE IF EXISTS backup_dr.orders_full_backup CASCADE;
DROP TABLE IF EXISTS backup_dr.order_details_full_backup CASCADE;
DROP TABLE IF EXISTS backup_dr.incremental_change_log CASCADE;

-- 2. YEDEKLEME GEÇMİŞİ TABLOSU

CREATE TABLE backup_dr.backup_history (
    backup_id SERIAL PRIMARY KEY,
    backup_type VARCHAR(30),
    backup_description TEXT,
    backup_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'SUCCESS'
);

-- 3. RECOVERY POINT TABLOSU

CREATE TABLE backup_dr.recovery_points (
    point_id SERIAL PRIMARY KEY,
    point_name VARCHAR(100),
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. ARTIK / FARK YEDEKLEME İÇİN CHANGE LOG TABLOSU

CREATE TABLE backup_dr.incremental_change_log (
    log_id SERIAL PRIMARY KEY,
    table_name VARCHAR(100),
    operation_type VARCHAR(20),
    record_id TEXT,
    old_data JSONB,
    new_data JSONB,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 9. YEDEKLEME ZAMANLAYICI TABLOSU

DROP TABLE IF EXISTS backup_dr.backup_schedule;

CREATE TABLE backup_dr.backup_schedule (
    schedule_id SERIAL PRIMARY KEY,
    backup_type VARCHAR(30),
    frequency VARCHAR(50),
    scheduled_time TIME,
    is_active BOOLEAN DEFAULT TRUE,
    description TEXT
);

INSERT INTO backup_dr.backup_schedule (
    backup_type,
    frequency,
    scheduled_time,
    description
)
VALUES
('FULL BACKUP', 'WEEKLY', '02:00:00', 'Haftalık tam yedekleme planı'),
('DIFFERENTIAL BACKUP', 'DAILY', '03:00:00', 'Günlük değişen verilerin yedeklenmesi'),
('INCREMENTAL BACKUP', 'HOURLY', '01:00:00', 'Saatlik işlem loglarının yedeklenmesi');
