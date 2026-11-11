import "server-only";

import { cookies } from "next/headers";
import { createClient } from "@/lib/supabase/server";

export type CompanyMembership = {
  companyId: string;
  role: string;
  displayName: string;
  legalName: string;
  currencyCode: string;
};

export async function getCompanyContext() {
  const supabase = await createClient();
  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError || !user) throw new Error("Authentication is required.");

  const { data: memberships, error: membershipError } = await supabase
    .from("company_memberships")
    .select("company_id, role")
    .eq("user_id", user.id)
    .eq("is_active", true);

  if (membershipError) throw new Error("Company access could not be verified.");
  if (!memberships?.length) throw new Error("No active V7 company membership is assigned.");

  const companyIds = memberships.map((membership) => membership.company_id);
  const { data: companies, error: companiesError } = await supabase
    .from("companies")
    .select("id, display_name, legal_name, currency_code")
    .in("id", companyIds)
    .eq("is_active", true);

  if (companiesError || !companies?.length) throw new Error("No active company workspace is available.");

  const roleByCompany = new Map(memberships.map((membership) => [membership.company_id, membership.role]));
  const available: CompanyMembership[] = companies.map((company) => ({
    companyId: company.id,
    role: roleByCompany.get(company.id) ?? "viewer",
    displayName: company.display_name,
    legalName: company.legal_name,
    currencyCode: company.currency_code
  }));

  const cookieStore = await cookies();
  const requestedId = cookieStore.get("bokan-active-company")?.value;
  const active = available.find((company) => company.companyId === requestedId) ?? available[0];

  return { supabase, user, companies: available, active };
}
