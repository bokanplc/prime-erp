import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json"
};

const allowedRoles = new Set(["sales", "staff", "manager", "accountant", "inventory", "hr"]);

function respond(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return respond(405, { error: "Method not allowed." });

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) {
    return respond(500, { error: "Secure invitation service is not configured." });
  }

  const authorization = req.headers.get("Authorization") || "";
  if (!authorization.startsWith("Bearer ")) return respond(401, { error: "A signed-in administrator session is required." });

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return respond(400, { error: "Request body must be valid JSON." });
  }

  const email = String(body.email || "").trim().toLowerCase();
  const fullName = String(body.full_name || "").trim();
  const role = String(body.role || "").trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return respond(400, { error: "Enter a valid email address." });
  if (!fullName || fullName.length > 120) return respond(400, { error: "Enter a name of 1 to 120 characters." });
  if (!allowedRoles.has(role)) return respond(400, { error: "That company role cannot be assigned through invitations." });

  const callerClient = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: authorization } }
  });
  const { data: callerData, error: callerError } = await callerClient.auth.getUser();
  const caller = callerData?.user;
  if (callerError || !caller) return respond(401, { error: "The administrator session is invalid or expired." });

  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false }
  });
  const { data: company, error: companyError } = await admin
    .from("companies").select("id").eq("code", "BLACKROCK").eq("is_active", true).single();
  if (companyError || !company) return respond(500, { error: "The active BlackRock company record could not be verified." });

  const { data: membership, error: membershipError } = await admin
    .from("company_memberships").select("role,is_active")
    .eq("company_id", company.id).eq("user_id", caller.id).eq("is_active", true).maybeSingle();
  if (membershipError) return respond(500, { error: "Administrator company membership could not be verified." });
  if (!membership || !["owner", "admin"].includes(membership.role)) {
    return respond(403, { error: "Only a BlackRock owner or administrator may invite company users." });
  }

  let invitedUser: { id: string } | null = null;
  let invitationSent = false;
  const redirectTo = Deno.env.get("APP_SITE_URL");
  const inviteOptions: { data: { full_name: string }; redirectTo?: string } = { data: { full_name: fullName } };
  if (redirectTo) inviteOptions.redirectTo = redirectTo;

  const { data: inviteData, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, inviteOptions);
  if (!inviteError && inviteData?.user) {
    invitedUser = inviteData.user;
    invitationSent = true;
  } else {
    const { data: usersData, error: usersError } = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
    if (usersError) return respond(400, { error: inviteError?.message || "Invitation could not be sent." });
    const existing = usersData.users.find(user => String(user.email || "").toLowerCase() === email);
    if (!existing) return respond(400, { error: inviteError?.message || "Invitation could not be sent." });
    invitedUser = existing;
  }

  if (invitedUser.id === caller.id) {
    return respond(409, { error: "You cannot change your own administrator role through the invitation form." });
  }

  const departmentLabels: Record<string, string> = {
    sales: "Sales",
    staff: "Data Entry",
    manager: "Sales Management",
    accountant: "Accounting",
    inventory: "Inventory",
    hr: "Human Resources"
  };

  const { error: upsertError } = await admin.from("company_memberships").upsert({
    company_id: company.id,
    user_id: invitedUser.id,
    role,
    is_active: true
  }, { onConflict: "company_id,user_id" });
  if (upsertError) {
    return respond(500, { error: "The invitation was created but company access could not be assigned. Retry from the administrator account." });
  }

  const { error: profileError } = await admin.from("profiles").upsert({
    id: invitedUser.id,
    company_id: company.id,
    full_name: fullName,
    email,
    department: departmentLabels[role],
    role
  }, { onConflict: "id" });
  if (profileError) {
    return respond(500, { error: "Company access was assigned, but the employee profile needs administrator review." });
  }

  return respond(200, {
    success: true,
    email,
    role,
    status: invitationSent ? "invited" : "existing_account_assigned"
  });
});
