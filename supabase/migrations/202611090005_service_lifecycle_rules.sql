-- Límites de capacidad y transiciones seguras del ciclo de una mudanza.
create or replace function public.enforce_customer_active_move_limit()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  active_count integer;
begin
  if new.status in ('completed', 'cancelled') then
    return new;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(new.customer_id::text, 0));
  select count(*) into active_count
  from public.move_requests
  where customer_id = new.customer_id
    and id <> new.id
    and status not in ('completed', 'cancelled');

  if active_count >= 2 then
    raise exception 'Un cliente solo puede tener 2 servicios activos al tiempo';
  end if;
  return new;
end;
$$;

create trigger enforce_customer_active_move_limit
before insert or update of customer_id, status on public.move_requests
for each row execute function public.enforce_customer_active_move_limit();

create or replace function public.driver_has_active_move(p_driver_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.move_requests
    where driver_id = p_driver_id
      and status not in ('completed', 'cancelled')
  );
$$;

revoke all on function public.driver_has_active_move(uuid) from public, anon;
grant execute on function public.driver_has_active_move(uuid) to authenticated;

drop policy if exists "moves_driver_read_available" on public.move_requests;
create policy "moves_driver_read_available" on public.move_requests for select
to authenticated using (
  status = 'requested'
  and driver_id is null
  and exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'driver'
  )
  and not public.driver_has_active_move((select auth.uid()))
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

  perform pg_advisory_xact_lock(hashtextextended(caller::text, 0));
  if exists (
    select 1 from public.move_requests
    where driver_id = caller and status not in ('completed', 'cancelled')
  ) then
    raise exception 'Finaliza tu servicio actual antes de tomar otro';
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

create or replace function public.cancel_move(p_move_id uuid)
returns public.move_status
language plpgsql
security definer
set search_path = ''
as $$
declare
  next_status public.move_status;
begin
  update public.move_requests
  set status = 'cancelled'
  where id = p_move_id
    and customer_id = (select auth.uid())
    and status not in ('completed', 'cancelled')
  returning status into next_status;

  if next_status is null then
    raise exception 'No puedes cancelar este servicio';
  end if;
  return next_status;
end;
$$;

create or replace function public.complete_move(p_move_id uuid)
returns public.move_status
language plpgsql
security definer
set search_path = ''
as $$
declare
  next_status public.move_status;
begin
  update public.move_requests
  set status = 'completed', completed_at = now()
  where id = p_move_id
    and (
      customer_id = (select auth.uid())
      or driver_id = (select auth.uid())
    )
    and status in ('driver_assigned', 'in_progress')
  returning status into next_status;

  if next_status is null then
    raise exception 'Este servicio todavía no puede finalizarse';
  end if;
  return next_status;
end;
$$;

revoke all on function public.cancel_move(uuid) from public, anon;
revoke all on function public.complete_move(uuid) from public, anon;
grant execute on function public.cancel_move(uuid) to authenticated;
grant execute on function public.complete_move(uuid) to authenticated;
