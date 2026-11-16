import { createClient } from "https://esm.sh/@supabase/supabase-js@2.119.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const token = (req.headers.get("Authorization") || "").replace(/^Bearer\\s+/i, "");
    if (!token) {
      return new Response(JSON.stringify({ error: "Sign-in required." }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: userData, error: userError } = await admin.auth.getUser(token);
    if (userError || !userData.user) {
      return new Response(JSON.stringify({ error: "Your session could not be verified." }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: access } = await admin.from("journal_user_access")
      .select("role,is_active").eq("user_id", userData.user.id).maybeSingle();
    if (!access?.is_active || access.role !== "admin") {
      return new Response(JSON.stringify({ error: "Only a journal administrator can invite employees." }), {
        status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const email = String(body.email || "").trim().toLowerCase();
    const role = String(body.role || "data_entry");
    if (!/^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$/.test(email)) throw new Error("Enter a valid employee email address.");
    if (!["data_entry", "viewer"].includes(role)) throw new Error("The selected role is not allowed.");

    const origin = req.headers.get("origin");
    const options = origin ? { redirectTo: origin } : undefined;
    const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, options);
    if (inviteError) throw inviteError;
    if (!invited.user?.id) throw new Error("The invitation was created but the user ID was not returned.");

    const { error: grantError } = await admin.from("journal_user_access").upsert({
      user_id: invited.user.id, role, is_active: true, invited_email: email, created_by: userData.user.id,
    }, { onConflict: "user_id" });
    if (grantError) throw grantError;

    return new Response(JSON.stringify({ success: true, email, role }), {
      status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : "Invitation failed." }), {
      status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
