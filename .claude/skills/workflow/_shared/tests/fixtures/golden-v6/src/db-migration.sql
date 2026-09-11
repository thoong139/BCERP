-- REQ-ID: REQ-DB-001
-- Initial schema migration

CREATE TABLE customers (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  customer_id INTEGER REFERENCES customers(id),
  total DECIMAL(10, 2) NOT NULL,
  status VARCHAR(50) DEFAULT 'pending'
);

-- Later migration: schema drift
ALTER TABLE customers ADD COLUMN phone VARCHAR(20);
DROP TABLE old_sessions;
