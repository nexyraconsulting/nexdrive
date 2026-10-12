-- NexDrive — required reference data (every environment, including production).
-- Apply after schema.sql: psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/seed.sql
-- Reference data required in every environment. Prices in pence, VAT inclusive. Run after all migrations.
-- monthly_price_pence = monthly equivalent shown in the UI; term_price_pence = amount charged per term
-- (also the "qualifying subscription value" for referral rewards). Placeholder prices — confirm before launch.
INSERT INTO subscription_plans (code, name, term_months, monthly_price_pence, term_price_pence, sort_order) VALUES
  ('1m', 'Monthly', 1, 2500, 2500, 1),
  ('12m', '12 months', 12, 2000, 24000, 2),
  ('24m', '24 months', 24, 1750, 42000, 3),
  ('36m', '36 months', 36, 1500, 54000, 4)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, term_months = EXCLUDED.term_months, monthly_price_pence = EXCLUDED.monthly_price_pence, term_price_pence = EXCLUDED.term_price_pence, sort_order = EXCLUDED.sort_order;
