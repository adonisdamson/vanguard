-- 0012_member_fields2.sql
-- Three requested field additions:
--   1. Residence (where the member lives — distinct from their voting location)
--   2. Livelihood (profession + employment_status already exist; exposed in form grouping)
--   3. Gender restricted to 'male' | 'female' (legal genders in Ghana)

alter table members add column if not exists residential_address text;
alter table members add column if not exists residence_town      text;

-- Convert free-text gender column to a strict enum
do $$ begin
  if not exists (select 1 from pg_type where typname = 'gender_type') then
    create type gender_type as enum ('male', 'female');
  end if;
end $$;

-- Normalise any existing data before altering the column type
update members set gender = lower(trim(gender)) where gender is not null;
update members set gender = 'male'   where gender in ('m', 'male', 'man');
update members set gender = 'female' where gender in ('f', 'female', 'woman');
update members set gender = null     where gender not in ('male', 'female');

alter table members alter column gender type gender_type using gender::gender_type;
