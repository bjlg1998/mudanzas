-- Roles de acceso seleccionables y observaciones visibles para cada mudanza.
alter table public.move_requests
  add column customer_notes text
  check (customer_notes is null or length(customer_notes) <= 500);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  requested_role public.app_role;
begin
  requested_role := case new.raw_user_meta_data ->> 'account_role'
    when 'driver' then 'driver'::public.app_role
    else 'customer'::public.app_role
  end;

  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
    requested_role
  );
  return new;
end;
$$;

-- Permite escoger portal solo mientras la cuenta aún no tenga actividad.
-- Nunca permite asignarse el rol de administrador.
create or replace function public.choose_my_role(p_role public.app_role)
returns public.app_role
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
begin
  if caller is null or p_role not in ('customer', 'driver') then
    raise exception 'Rol no permitido';
  end if;

  if exists (
    select 1 from public.move_requests
    where customer_id = caller or driver_id = caller
  ) or exists (
    select 1 from public.vehicles where driver_id = caller
  ) then
    if not exists (
      select 1 from public.profiles where id = caller and role = p_role
    ) then
      raise exception 'La cuenta ya tiene un tipo de acceso asignado';
    end if;
    return p_role;
  end if;

  update public.profiles
  set role = p_role
  where id = caller and role <> 'admin';

  return p_role;
end;
$$;

revoke all on function public.choose_my_role(public.app_role) from public;
grant execute on function public.choose_my_role(public.app_role) to authenticated;

drop policy if exists "moves_customer_create" on public.move_requests;
create policy "moves_customer_create" on public.move_requests for insert
to authenticated with check (
  customer_id = (select auth.uid())
  and driver_id is null
  and exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'customer'
  )
);
