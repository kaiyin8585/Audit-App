// Audit Tracker — admin-only user management.
// The service-role key never leaves this function; callers must be signed-in admins.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const EMAIL_DOMAIN = "auditapp.local";
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
const USERNAME = /^[a-z0-9][a-z0-9._-]{1,31}$/;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });

  // Identify the caller from their access token and require the admin role
  const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  const { data: who, error: whoErr } = await admin.auth.getUser(token);
  if (whoErr || !who?.user) return json({ error: "Not signed in" }, 401);
  const { data: me } = await admin.from("profiles").select("role").eq("id", who.user.id).single();
  if (me?.role !== "admin") return json({ error: "Only administrators can manage users" }, 403);

  let body: Record<string, unknown> = {};
  try { body = await req.json(); } catch { return json({ error: "Invalid JSON body" }, 400); }
  const action = String(body.action || "");

  const adminCount = async () => {
    const { count } = await admin.from("profiles").select("id", { count: "exact", head: true }).eq("role", "admin");
    return count ?? 0;
  };
  const checkPassword = (p: unknown) => typeof p === "string" && p.length >= 6 && p.length <= 72;

  try {
    if (action === "create") {
      const username = String(body.username || "").trim().toLowerCase();
      const display_name = String(body.display_name || "").trim() || username.charAt(0).toUpperCase() + username.slice(1);
      const role = body.role === "admin" ? "admin" : "auditor";
      const password = body.password;
      if (!USERNAME.test(username)) return json({ error: "Username must be 2–32 characters: lowercase letters, numbers, dot, dash or underscore" }, 400);
      if (!checkPassword(password)) return json({ error: "Initial password must be 6–72 characters" }, 400);
      const { data: exists } = await admin.from("profiles").select("id").eq("username", username).maybeSingle();
      if (exists) return json({ error: `Username “${username}” is already taken` }, 409);
      const { data, error } = await admin.auth.admin.createUser({
        email: `${username}@${EMAIL_DOMAIN}`,
        password: password as string,
        email_confirm: true,
        user_metadata: { username, display_name },
        app_metadata: { role },
      });
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true, id: data.user?.id });
    }

    const userId = String(body.user_id || "");
    if (!userId) return json({ error: "user_id is required" }, 400);
    const { data: target } = await admin.from("profiles").select("id, role, username").eq("id", userId).maybeSingle();
    if (!target) return json({ error: "User not found" }, 404);

    if (action === "reset_password") {
      if (!checkPassword(body.password)) return json({ error: "Password must be 6–72 characters" }, 400);
      const { error } = await admin.auth.admin.updateUserById(userId, { password: body.password as string });
      if (error) return json({ error: error.message }, 400);
      await admin.from("profiles").update({ must_change_password: true }).eq("id", userId);
      return json({ ok: true });
    }

    if (action === "update") {
      const patch: Record<string, unknown> = {};
      if (typeof body.display_name === "string") patch.display_name = body.display_name.trim().slice(0, 80);
      if (body.role === "admin" || body.role === "auditor") {
        if (target.role === "admin" && body.role !== "admin" && (await adminCount()) <= 1)
          return json({ error: "There must be at least one administrator" }, 400);
        patch.role = body.role;
        await admin.auth.admin.updateUserById(userId, { app_metadata: { role: body.role } });
      }
      const { error } = await admin.from("profiles").update(patch).eq("id", userId);
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true });
    }

    if (action === "delete") {
      if (userId === who.user.id) return json({ error: "You cannot delete your own account" }, 400);
      if (target.role === "admin" && (await adminCount()) <= 1) return json({ error: "There must be at least one administrator" }, 400);
      const { error } = await admin.auth.admin.deleteUser(userId);
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true });
    }

    return json({ error: `Unknown action “${action}”` }, 400);
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : "Unexpected error" }, 500);
  }
});
