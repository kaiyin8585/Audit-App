-- Sample users for a fresh project: priya (admin), dan and marcus (auditors).
-- Initial password for all three is "password"; the app forces each user to choose
-- a new one at first sign-in. Sign in with the username only (the app appends
-- @auditapp.local). Prefer creating real users from the app's Users page.
do $$
declare u record; v_id uuid;
begin
  for u in select * from (values ('priya','Priya','admin'), ('dan','Dan','auditor'), ('marcus','Marcus','auditor')) as t(username, display_name, role)
  loop
    continue when exists (select 1 from auth.users where email = u.username || '@auditapp.local');
    v_id := gen_random_uuid();
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change)
    values ('00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
      u.username || '@auditapp.local', extensions.crypt('password', extensions.gen_salt('bf')), now(),
      jsonb_build_object('provider','email','providers',jsonb_build_array('email'),'role',u.role),
      jsonb_build_object('username',u.username,'display_name',u.display_name), now(), now(), '', '', '', '');
    insert into auth.identities (user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
    values (v_id, v_id::text, jsonb_build_object('sub', v_id::text, 'email', u.username || '@auditapp.local', 'email_verified', true), 'email', now(), now(), now());
  end loop;
end $$;
