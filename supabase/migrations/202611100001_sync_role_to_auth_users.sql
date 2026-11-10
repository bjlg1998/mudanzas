-- Expone el tipo de cuenta en Auth > Users mediante app_metadata.
-- public.profiles.role continúa siendo la fuente de verdad y app_metadata no
-- puede ser modificada directamente por el usuario autenticado.
create or replace function public.sync_profile_role_to_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update auth.users
  set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
    || jsonb_build_object('account_role', new.role::text)
  where id = new.id;
  return new;
end;
$$;

create trigger sync_profile_role_to_auth_user
after insert or update of role on public.profiles
for each row execute function public.sync_profile_role_to_auth_user();

-- Sincroniza las cuentas que fueron creadas antes de esta migración.
update auth.users as users
set raw_app_meta_data = coalesce(users.raw_app_meta_data, '{}'::jsonb)
  || jsonb_build_object('account_role', profiles.role::text)
from public.profiles as profiles
where profiles.id = users.id;
