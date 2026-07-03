-- Returns monthly registration count for the last 6 months
-- Used by the Higher Authority dashboard trend chart
create or replace function public.get_registration_trend()
returns table(month text, count bigint)
language sql stable security definer as $$
  select
    to_char(date_trunc('month', created_at), 'Mon ''YY') as month,
    count(*)::bigint as count
  from members
  where created_at >= date_trunc('month', now()) - interval '5 months'
  group by date_trunc('month', created_at)
  order by date_trunc('month', created_at);
$$;

-- Returns per-status totals across all members
-- Higher Authority and Admin can call this
create or replace function public.get_member_status_counts()
returns table(status text, count bigint)
language sql stable security definer as $$
  select status::text, count(*)::bigint
  from members
  group by status;
$$;
