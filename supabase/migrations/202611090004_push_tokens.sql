-- Tokens FCM por instalación. Cada usuario solo administra sus dispositivos.
create table public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique check (length(token) > 20),
  platform text not null default 'android',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index push_tokens_user_idx on public.push_tokens(user_id);

create trigger push_tokens_updated_at before update on public.push_tokens
for each row execute function public.set_updated_at();

alter table public.push_tokens enable row level security;

create policy "push_tokens_own_read" on public.push_tokens for select
to authenticated using (user_id = (select auth.uid()));

create policy "push_tokens_own_insert" on public.push_tokens for insert
to authenticated with check (user_id = (select auth.uid()));

create policy "push_tokens_own_update" on public.push_tokens for update
to authenticated using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy "push_tokens_own_delete" on public.push_tokens for delete
to authenticated using (user_id = (select auth.uid()));
