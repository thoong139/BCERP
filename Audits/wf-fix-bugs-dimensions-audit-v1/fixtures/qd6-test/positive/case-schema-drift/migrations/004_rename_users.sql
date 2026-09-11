-- Migration: rename users table (PENDING — DANGEROUS)
-- WARNING: Renames break all existing queries and ORM references.
ALTER TABLE users RENAME TO accounts;
ALTER TABLE accounts RENAME COLUMN username TO account_name;
