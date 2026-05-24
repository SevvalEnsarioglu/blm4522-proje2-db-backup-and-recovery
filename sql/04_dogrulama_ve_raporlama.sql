/* =========================================================
   NORTHWIND DATABASE BACKUP & DISASTER RECOVERY PLAN
   Dosya: 04_dogrulama_ve_raporlama.sql
   ========================================================= */

-- =========================================================
-- 14. TEST YEDEKLEME SENARYOLARI
-- =========================================================

DROP TABLE IF EXISTS backup_dr.backup_validation_results;

CREATE TABLE backup_dr.backup_validation_results (
    validation_id SERIAL PRIMARY KEY,
    table_name VARCHAR(100),
    original_count INT,
    backup_count INT,
    validation_status VARCHAR(20),
    checked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO backup_dr.backup_validation_results (
    table_name,
    original_count,
    backup_count,
    validation_status
)
SELECT
    'products',
    (SELECT COUNT(*) FROM products),
    (SELECT COUNT(*) FROM backup_dr.products_full_backup),
    CASE
        WHEN (SELECT COUNT(*) FROM products) = (SELECT COUNT(*) FROM backup_dr.products_full_backup)
        THEN 'VALID'
        ELSE 'CHECK REQUIRED'
    END;

INSERT INTO backup_dr.backup_validation_results (
    table_name,
    original_count,
    backup_count,
    validation_status
)
SELECT
    'orders',
    (SELECT COUNT(*) FROM orders),
    (SELECT COUNT(*) FROM backup_dr.orders_full_backup),
    CASE
        WHEN (SELECT COUNT(*) FROM orders) = (SELECT COUNT(*) FROM backup_dr.orders_full_backup)
        THEN 'VALID'
        ELSE 'CHECK REQUIRED'
    END;

INSERT INTO backup_dr.backup_validation_results (
    table_name,
    original_count,
    backup_count,
    validation_status
)
SELECT
    'order_details',
    (SELECT COUNT(*) FROM order_details),
    (SELECT COUNT(*) FROM backup_dr.order_details_full_backup),
    CASE
        WHEN (SELECT COUNT(*) FROM order_details) = (SELECT COUNT(*) FROM backup_dr.order_details_full_backup)
        THEN 'VALID'
        ELSE 'CHECK REQUIRED'
    END;

-- =========================================================
-- 15. DATABASE MIRRORING SİMÜLASYONU
-- =========================================================

DROP SCHEMA IF EXISTS mirror_db CASCADE;

CREATE SCHEMA mirror_db;

CREATE TABLE mirror_db.products_mirror AS
SELECT * FROM products;

CREATE TABLE mirror_db.orders_mirror AS
SELECT * FROM orders;

CREATE TABLE mirror_db.order_details_mirror AS
SELECT * FROM order_details;

INSERT INTO backup_dr.backup_history (
    backup_type,
    backup_description
)
VALUES (
    'DATABASE MIRRORING',
    'Products, Orders ve Order Details tabloları mirror_db şemasına kopyalandı.'
);

-- =========================================================
-- 16. RAPORLAMA SORGULARI
-- =========================================================

SELECT *
FROM backup_dr.backup_history
ORDER BY backup_time;

SELECT *
FROM backup_dr.recovery_points
ORDER BY created_at;

SELECT *
FROM backup_dr.incremental_change_log
ORDER BY changed_at;

SELECT *
FROM backup_dr.backup_schedule;

SELECT *
FROM backup_dr.backup_validation_results;

SELECT
    p.product_id,
    p.product_name,
    p.unit_price AS original_price,
    m.unit_price AS mirror_price
FROM products p
JOIN mirror_db.products_mirror m
    ON p.product_id = m.product_id
ORDER BY p.product_id
LIMIT 10;
