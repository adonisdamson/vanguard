-- Auto-generate member numbers: NDC-TW-YYMM-NNNNN
-- e.g. NDC-TW-2507-00001

create sequence if not exists member_number_seq start 1;

create or replace function public.generate_member_number()
returns trigger language plpgsql security definer as $$
begin
  if new.member_number is null or new.member_number = '' then
    new.member_number :=
      'NDC-TW-' ||
      to_char(now(), 'YYMM') || '-' ||
      lpad(nextval('member_number_seq')::text, 5, '0');
  end if;
  return new;
end;
$$;

create trigger trg_generate_member_number
before insert on members
for each row execute function generate_member_number();
