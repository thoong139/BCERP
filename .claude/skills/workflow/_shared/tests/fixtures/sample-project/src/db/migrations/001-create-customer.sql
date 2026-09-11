-- Migration: Create customer table
-- QD6 issue: Missing down() function for rollback

CREATE TABLE customers (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Missing: down() function for rollback
-- Should include: reverse migration logic
