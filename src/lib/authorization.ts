import "server-only";
import { createClient } from "@/lib/supabase/server";

export const COMPANY_ROLES = ["owner", "manager", "sales", "purchasing", "operations", "viewer"] as const;
export type CompanyRole = (typeof COMPANY_ROLES)[number];

export class AuthorizationError extends Error {
  constructor(message = "You do not have permission to perform this action.") {
    super(message);
    this.name = "AuthorizationError";
  }
}

export async function requireCompanyRole(companyId: string, allowedRoles: readonly CompanyRole[]) {
  if (!companyId || !/^[0-9a-f-]{36}$/i.test(companyId)) {
    throw new AuthorizationError("A valid company context is required.");
  }

  const supabase = await createClient();
  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError || !user) throw new AuthorizationError("Sign in is required.");

  const { data: membership, error } = await supabase
    .from("company_memberships")
    .select("company_id, role, is_active")
    .eq("company_id", companyId)
    .eq("user_id", user.id)
    .eq("is_active", true)
    .maybeSingle();

  if (error || !membership) throw new AuthorizationError("You are not an active member of this company.");
  if (!allowedRoles.includes(membership.role as CompanyRole)) {
    throw new AuthorizationError("Your company role does not allow this action.");
  }

  return { supabase, user, membership: membership as { company_id: string; role: CompanyRole; is_active: boolean } };
}

export async function appendAuditEvent(input: {
  companyId: string;
  action: string;
  entityTable: string;
  entityId?: string;
  metadata?: Record<string, unknown>;
}) {
  const { supabase, user } = await requireCompanyRole(input.companyId, COMPANY_ROLES.filter((role) => role !== "viewer"));
  const { error } = await supabase.from("audit_events").insert({
    company_id: input.companyId,
    actor_user_id: user.id,
    action: input.action,
    entity_table: input.entityTable,
    entity_id: input.entityId ?? null,
    metadata: input.metadata ?? {}
  });
  if (error) throw new Error("The action could not be recorded in the audit trail.");
}
