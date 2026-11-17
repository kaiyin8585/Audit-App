-- Audit Tracker schema (applied to project efcrblpnggfwcgjrezfr on 2026-11-17)
-- Tables: profiles, engagements, workbooks, issues. Passwords live only in auth.users.

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9][a-z0-9._-]{1,31}$'),
  display_name text,
  role text not null default 'auditor' check (role in ('admin','auditor')),
  must_change_password boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.engagements (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Audit engagement',
  entity text not null default '',
  fy_end date,
  currency text not null default 'SGD',
  overall_materiality numeric not null default 500000 check (overall_materiality >= 0),
  pm_pct numeric not null default 75 check (pm_pct between 0 and 100),
  ct_pct numeric not null default 5 check (ct_pct between 0 and 100),
  round_min numeric not null default 10000 check (round_min >= 0),
  approval_limit numeric not null default 5000 check (approval_limit >= 0),
  tests jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.workbooks (
  id uuid primary key default gen_random_uuid(),
  engagement_id uuid not null references public.engagements(id) on delete cascade,
  name text not null,
  size_bytes bigint not null default 0,
  sheets jsonb not null default '[]'::jsonb,
  uploaded_by uuid references auth.users(id) on delete set null default auth.uid(),
  uploaded_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (engagement_id, name)
);

create table public.issues (
  id uuid primary key default gen_random_uuid(),
  engagement_id uuid not null references public.engagements(id) on delete cascade,
  ref text not null,
  issue_key text,
  source text not null default 'manual' check (source in ('auto','manual')),
  test text not null default 'manual',
  title text not null default '',
  description text not null default '',
  amount numeric not null default 0,
  risk text not null default 'Medium' check (risk in ('Low','Medium','High','Significant')),
  priority text not null default 'P2' check (priority in ('P1','P2','P3')),
  status text not null default 'Open' check (status in ('Open','In review','Resolved','Not an issue')),
  assertion text not null default '',
  workbook_id uuid references public.workbooks(id) on delete set null,
  file_name text not null default '',
  sheet text not null default '',
  cell_ref text not null default '',
  ssa_refs text[] not null default '{}',
  sfrs_refs text[] not null default '{}',
  notes text not null default '',
  response text not null default '',
  detail jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index workbooks_engagement_idx on public.workbooks(engagement_id);
create index issues_engagement_idx on public.issues(engagement_id);
create index issues_workbook_idx on public.issues(workbook_id);
create index issues_engagement_key_idx on public.issues(engagement_id, issue_key);
create index engagements_created_by_idx on public.engagements(created_by);
create index engagements_updated_by_idx on public.engagements(updated_by);
create index workbooks_uploaded_by_idx on public.workbooks(uploaded_by);
create index issues_created_by_idx on public.issues(created_by);
create index issues_updated_by_idx on public.issues(updated_by);

-- Helpers ------------------------------------------------------------
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin'); $$;
revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

create or replace function public.touch_row()
returns trigger language plpgsql set search_path = ''
as $$
begin
  new.updated_at := now();
  if tg_table_name <> 'profiles' and tg_table_name <> 'workbooks' then new.updated_by := auth.uid(); end if;
  return new;
end; $$;
create trigger profiles_touch before update on public.profiles for each row execute function public.touch_row();
create trigger engagements_touch before insert or update on public.engagements for each row execute function public.touch_row();
create trigger workbooks_touch before update on public.workbooks for each row execute function public.touch_row();
create trigger issues_touch before insert or update on public.issues for each row execute function public.touch_row();

-- New auth user -> profile (username/display name from user metadata, role from app metadata)
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  v_username text := lower(coalesce(nullif(new.raw_user_meta_data->>'username',''), split_part(new.email,'@',1)));
  v_role text := coalesce(nullif(new.raw_app_meta_data->>'role',''), 'auditor');
begin
  if v_role not in ('admin','auditor') then v_role := 'auditor'; end if;
  insert into public.profiles (id, username, display_name, role, must_change_password)
  values (new.id, v_username, coalesce(nullif(new.raw_user_meta_data->>'display_name',''), initcap(v_username)), v_role, true);
  return new;
end; $$;
revoke all on function public.handle_new_user() from public, anon, authenticated;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

-- Signed-in user clears their own "must change password" flag after changing it
create or replace function public.password_changed()
returns void language sql security definer set search_path = ''
as $$ update public.profiles set must_change_password = false where id = (select auth.uid()); $$;
revoke all on function public.password_changed() from public, anon;
grant execute on function public.password_changed() to authenticated;

-- Row level security ---------------------------------------------------
alter table public.profiles enable row level security;
alter table public.engagements enable row level security;
alter table public.workbooks enable row level security;
alter table public.issues enable row level security;

create policy "Team can view profiles" on public.profiles for select to authenticated using (true);
create policy "Users update own profile" on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
revoke all on public.profiles from anon;
revoke insert, update, delete on public.profiles from authenticated;
grant select on public.profiles to authenticated;
grant update (display_name) on public.profiles to authenticated;

create policy "Team can view engagements" on public.engagements for select to authenticated using (true);
create policy "Team can create engagements" on public.engagements for insert to authenticated with check ((select auth.uid()) is not null);
create policy "Team can update engagements" on public.engagements for update to authenticated using (true) with check (true);
create policy "Admins delete engagements" on public.engagements for delete to authenticated using ((select public.is_admin()));

create policy "Team can view workbooks" on public.workbooks for select to authenticated using (true);
create policy "Team can add workbooks" on public.workbooks for insert to authenticated with check ((select auth.uid()) is not null);
create policy "Team can update workbooks" on public.workbooks for update to authenticated using (true) with check (true);
create policy "Team can remove workbooks" on public.workbooks for delete to authenticated using (true);

create policy "Team can view issues" on public.issues for select to authenticated using (true);
create policy "Team can add issues" on public.issues for insert to authenticated with check ((select auth.uid()) is not null);
create policy "Team can update issues" on public.issues for update to authenticated using (true) with check (true);
create policy "Team can delete issues" on public.issues for delete to authenticated using (true);

revoke all on public.engagements, public.workbooks, public.issues from anon;
grant select, insert, update, delete on public.engagements, public.workbooks, public.issues to authenticated;
