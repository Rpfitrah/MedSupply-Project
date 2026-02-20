-- Active: 1771220958691@@localhost@5432@medsupply
-- Active: 1771220958691@@localhost@5432@medsupply@public

CREATE DATABASE MedSupply;

CREATE TABLE public.master_products   -- create master products table with primary key
(
    product_code VARCHAR PRIMARY KEY,
    product_name TEXT,
    product_type TEXT,
    stock_available FLOAT,
    inden_lead_time_days FLOAT,
    supplier_cost FLOAT
);

CREATE TABLE public.customers    -- create customers table with primary key
(
    customer_id VARCHAR PRIMARY KEY,
    customer_name TEXT,
    facility_type TEXT,
    PIC_name TEXT,
    PIC_phone TEXT,
    total_transaction FLOAT
);

CREATE TABLE public.transactions_main   -- lreate transactions main table with primary key
(
    transaction_id VARCHAR PRIMARY KEY,
    customer_id VARCHAR,
    order_date DATE,
    delivery_date DATE,
    grand_total FLOAT,
    invoice_status TEXT,
   
    FOREIGN KEY (customer_id) REFERENCES public.customers (customer_id) -- memastikan bahwa **customer_id** ada di tabel **customers**
);

CREATE TABLE public.transactions_item  -- create transactions item table with composite foreign keys
(
    transaction_id VARCHAR,
    product_type TEXT,
    product_code VARCHAR,
    product_name TEXT,
    unit_price FLOAT,
    quantity FLOAT,
    item_total FLOAT,
    inden_status TEXT,
   
    FOREIGN KEY (transaction_id) REFERENCES public.transactions_main (transaction_id), -- memastikan bahwa **transaction_id** ada di tabel **transactions_main**
    FOREIGN KEY (product_code) REFERENCES public.master_products (product_code) -- memastikan bahwa **product_code** ada di tabel **master_products**
);

/*
\copy master_products FROM 'C:\Users\FITRAH\OneDrive - Virtual Education Academy\Portfolio\Syntetics Data\MedSupply Analytics Dashboard\Master_Products.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');
\copy customers FROM 'C:\Users\FITRAH\OneDrive - Virtual Education Academy\Portfolio\Syntetics Data\MedSupply Analytics Dashboard\Customers.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');
\copy transactions_main FROM 'C:\Users\FITRAH\OneDrive - Virtual Education Academy\Portfolio\Syntetics Data\MedSupply Analytics Dashboard\Transactions_Main.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');
\copy transactions_item FROM 'C:\Users\FITRAH\OneDrive - Virtual Education Academy\Portfolio\Syntetics Data\MedSupply Analytics Dashboard\Transaction_Items.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');


*/

DROP Table IF EXISTS public.master_products;
DROP Table IF EXISTS public.customers;
DROP Table IF EXISTS public.transactions_main;
DROP Table IF EXISTS public.transactions_item;