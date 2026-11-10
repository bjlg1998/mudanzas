-- Vista administrativa para consultar usuarios y su tipo de cuenta en una sola tabla.
-- Se mantiene sin permisos para los roles usados por la aplicacion: solo puede
-- consultarse desde el Dashboard/SQL Editor con privilegios administrativos.
create or replace view public.user_admin_overview
with (security_invoker = true)
as
select
  users.id as uid,
  coalesce(
    nullif(trim(profiles.full_name), ''),
    nullif(trim(users.raw_user_meta_data ->> 'full_name'), ''),
    nullif(trim(users.raw_user_meta_data ->> 'name'), '')
  ) as display_name,
  users.email,
  coalesce(profiles.phone, users.phone) as phone,
  users.raw_app_meta_data ->> 'provider' as provider,
  coalesce(
    users.raw_app_meta_data ->> 'account_role',
    profiles.role::text
  ) as account_role,
  users.email_confirmed_at,
  users.last_sign_in_at,
  users.created_at
from auth.users as users
left join public.profiles as profiles on profiles.id = users.id;

comment on view public.user_admin_overview is
  'Vista de solo lectura para administrar usuarios y consultar account_role desde el Dashboard.';

revoke all on table public.user_admin_overview from public;
revoke all on table public.user_admin_overview from anon;
revoke all on table public.user_admin_overview from authenticated;
