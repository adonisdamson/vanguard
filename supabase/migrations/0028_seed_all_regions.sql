-- 0028_seed_all_regions.sql
-- Seeds all 16 official Ghana regions (Electoral Commission / GSS 2019 list).
-- Greater Accra was already seeded by 0013; all inserts are idempotent.
insert into regions (name) values
  ('Ahafo'),
  ('Ashanti'),
  ('Bono'),
  ('Bono East'),
  ('Central'),
  ('Eastern'),
  ('Greater Accra'),
  ('North East'),
  ('Northern'),
  ('Oti'),
  ('Savannah'),
  ('Upper East'),
  ('Upper West'),
  ('Volta'),
  ('Western'),
  ('Western North')
on conflict (name) do nothing;
