-- Bandeja de servicios disponibles y toma atómica por parte de conductores.
create policy "moves_driver_read_available" on public.move_requests for select
to authenticated using (
  status = 'requested'
  and driver_id is null
  and exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'driver'
  )
);

create or replace function public.claim_available_move(p_move_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
  claimed_id uuid;
begin
  if caller is null or not exists (
    select 1 from public.profiles
    where id = caller and role = 'driver'
  ) then
    raise exception 'Solo un conductor puede tomar servicios';
  end if;

  update public.move_requests
  set driver_id = caller, status = 'driver_assigned'
  where id = p_move_id
    and status = 'requested'
    and driver_id is null
  returning id into claimed_id;

  if claimed_id is null then
    raise exception 'Este servicio ya fue tomado por otro conductor';
  end if;

  return claimed_id;
end;
$$;

revoke all on function public.claim_available_move(uuid) from public, anon;
grant execute on function public.claim_available_move(uuid) to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'move_requests'
  ) then
    alter publication supabase_realtime add table public.move_requests;
  end if;
end;
$$;
