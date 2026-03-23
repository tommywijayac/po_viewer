
CREATE TABLE "purchase_order_histories" (
    id BIGSERIAL PRIMARY KEY,
    po_date DATE,
    po_number VARCHAR(255),
    vendor_name VARCHAR(255),
    project_name VARCHAR(255),
    product_name VARCHAR(255),
    product_qty INTEGER,
    product_qty_unit VARCHAR(32),
    product_unit_price NUMERIC,
    product_discount_pct NUMERIC,
    product_final_price NUMERIC,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)