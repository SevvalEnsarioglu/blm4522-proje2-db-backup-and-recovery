-- 10. TEST VERİ DEĞİŞİKLİKLERİ

UPDATE products
SET unit_price = unit_price + 5
WHERE product_id = 1;

INSERT INTO backup_dr.backup_history (
    backup_type,
    backup_description
)
VALUES (
    'DIFFERENTIAL BACKUP',
    'Product tablosunda değişen kayıtlar incremental_change_log tablosuna kaydedildi.'
);

-- 11. FELAKET SENARYOSU: YANLIŞLIKLA VERİ SİLME

INSERT INTO backup_dr.recovery_points (
    point_name,
    description
)
VALUES (
    'RP_BEFORE_DELETE_ORDER',
    'Order silme işleminden hemen önce oluşturulan recovery point.'
);

DELETE FROM order_details
WHERE order_id = 10248;

DELETE FROM orders
WHERE order_id = 10248;

INSERT INTO backup_dr.backup_history (
    backup_type,
    backup_description
)
VALUES (
    'DISASTER SCENARIO',
    '10248 numaralı sipariş yanlışlıkla silindi.'
);

-- 12. SİLİNEN ORDER VERİSİNİ TAM YEDEKTEN GERİ YÜKLEME

INSERT INTO orders
SELECT *
FROM backup_dr.orders_full_backup
WHERE order_id = 10248
AND NOT EXISTS (
    SELECT 1
    FROM orders
    WHERE orders.order_id = 10248
);

INSERT INTO order_details
SELECT *
FROM backup_dr.order_details_full_backup
WHERE order_id = 10248
AND NOT EXISTS (
    SELECT 1
    FROM order_details od
    WHERE od.order_id = backup_dr.order_details_full_backup.order_id
      AND od.product_id = backup_dr.order_details_full_backup.product_id
);

INSERT INTO backup_dr.backup_history (
    backup_type,
    backup_description
)
VALUES (
    'RESTORE',
    '10248 numaralı sipariş ve detayları tam yedekten geri yüklendi.'
);

-- 13. POINT-IN-TIME RESTORE MANTIĞI

DROP TABLE IF EXISTS backup_dr.products_pitr_demo;

CREATE TABLE backup_dr.products_pitr_demo AS
SELECT * FROM products;

UPDATE products
SET unit_price = 999
WHERE product_id = 2;

INSERT INTO backup_dr.backup_history (
    backup_type,
    backup_description
)
VALUES (
    'POINT-IN-TIME TEST',
    'Product 2 üzerinde hatalı fiyat güncellemesi yapıldı.'
);

UPDATE products p
SET
    product_name = b.product_name,
    supplier_id = b.supplier_id,
    category_id = b.category_id,
    quantity_per_unit = b.quantity_per_unit,
    unit_price = b.unit_price,
    units_in_stock = b.units_in_stock,
    units_on_order = b.units_on_order,
    reorder_level = b.reorder_level,
    discontinued = b.discontinued
FROM backup_dr.products_pitr_demo b
WHERE p.product_id = b.product_id
  AND p.product_id = 2;

INSERT INTO backup_dr.backup_history (
    backup_type,
    backup_description
)
VALUES (
    'POINT-IN-TIME RESTORE',
    'Product 2 hatalı güncellemeden önceki haline döndürüldü.'
);
