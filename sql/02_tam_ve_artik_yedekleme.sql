-- 4. TAM YEDEKLEME TABLOLARI

CREATE TABLE backup_dr.products_full_backup AS
SELECT * FROM products;

CREATE TABLE backup_dr.orders_full_backup AS
SELECT * FROM orders;

CREATE TABLE backup_dr.order_details_full_backup AS
SELECT * FROM order_details;

INSERT INTO backup_dr.backup_history (
    backup_type,
    backup_description
)
VALUES (
    'FULL BACKUP',
    'Products, Orders ve Order Details tablolarının tam yedeği alındı.'
);

INSERT INTO backup_dr.recovery_points (
    point_name,
    description
)
VALUES (
    'RP_BEFORE_DISASTER',
    'Felaket senaryosu öncesi güvenli kurtarma noktası oluşturuldu.'
);

-- 6. PRODUCTS İÇİN LOG TRIGGER FUNCTION

CREATE OR REPLACE FUNCTION backup_dr.log_products_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO backup_dr.incremental_change_log (
            table_name,
            operation_type,
            record_id,
            old_data,
            new_data
        )
        VALUES (
            'products',
            TG_OP,
            NEW.product_id::TEXT,
            NULL,
            to_jsonb(NEW)
        );

        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO backup_dr.incremental_change_log (
            table_name,
            operation_type,
            record_id,
            old_data,
            new_data
        )
        VALUES (
            'products',
            TG_OP,
            NEW.product_id::TEXT,
            to_jsonb(OLD),
            to_jsonb(NEW)
        );

        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO backup_dr.incremental_change_log (
            table_name,
            operation_type,
            record_id,
            old_data,
            new_data
        )
        VALUES (
            'products',
            TG_OP,
            OLD.product_id::TEXT,
            to_jsonb(OLD),
            NULL
        );

        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_products_incremental_backup ON products;

CREATE TRIGGER trg_products_incremental_backup
AFTER INSERT OR UPDATE OR DELETE ON products
FOR EACH ROW
EXECUTE FUNCTION backup_dr.log_products_changes();

-- 7. ORDERS İÇİN LOG TRIGGER FUNCTION

CREATE OR REPLACE FUNCTION backup_dr.log_orders_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO backup_dr.incremental_change_log
        VALUES (
            DEFAULT,
            'orders',
            TG_OP,
            NEW.order_id::TEXT,
            NULL,
            to_jsonb(NEW),
            CURRENT_TIMESTAMP
        );

        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO backup_dr.incremental_change_log
        VALUES (
            DEFAULT,
            'orders',
            TG_OP,
            NEW.order_id::TEXT,
            to_jsonb(OLD),
            to_jsonb(NEW),
            CURRENT_TIMESTAMP
        );

        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO backup_dr.incremental_change_log
        VALUES (
            DEFAULT,
            'orders',
            TG_OP,
            OLD.order_id::TEXT,
            to_jsonb(OLD),
            NULL,
            CURRENT_TIMESTAMP
        );

        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_orders_incremental_backup ON orders;

CREATE TRIGGER trg_orders_incremental_backup
AFTER INSERT OR UPDATE OR DELETE ON orders
FOR EACH ROW
EXECUTE FUNCTION backup_dr.log_orders_changes();

-- 8. ORDER_DETAILS İÇİN LOG TRIGGER FUNCTION

CREATE OR REPLACE FUNCTION backup_dr.log_order_details_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO backup_dr.incremental_change_log
        VALUES (
            DEFAULT,
            'order_details',
            TG_OP,
            OLD.order_id::TEXT || '-' || OLD.product_id::TEXT,
            NULL,
            to_jsonb(NEW),
            CURRENT_TIMESTAMP
        );

        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO backup_dr.incremental_change_log
        VALUES (
            DEFAULT,
            'order_details',
            TG_OP,
            NEW.order_id::TEXT || '-' || NEW.product_id::TEXT,
            to_jsonb(OLD),
            to_jsonb(NEW),
            CURRENT_TIMESTAMP
        );

        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO backup_dr.incremental_change_log
        VALUES (
            DEFAULT,
            'order_details',
            TG_OP,
            OLD.order_id::TEXT || '-' || OLD.product_id::TEXT,
            to_jsonb(OLD),
            NULL,
            CURRENT_TIMESTAMP
        );

        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_order_details_incremental_backup ON order_details;

CREATE TRIGGER trg_order_details_incremental_backup
AFTER INSERT OR UPDATE OR DELETE ON order_details
FOR EACH ROW
EXECUTE FUNCTION backup_dr.log_order_details_changes();
