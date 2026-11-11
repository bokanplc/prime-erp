import "server-only";
import { createClient } from "@/lib/supabase/server";

export type AuthorizedCompany = {
  id: string;
  display_name: string;
  role: string;
};

export async function getAuthorizedCompanies(): Promise<AuthorizedCompany[]> {
  const supabase = await createClient();
  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError || !user) return [];

  const { data: memberships, error: membershipError } = await supabase
    .from("company_memberships")
    .select("company_id, role")
    .eq("user_id", user.id)
    .eq("is_active", true);

  if (membershipError || !memberships?.length) return [];

  const { data: companies, error: companyError } = await supabase
    .from("companies")
    .select("id, display_name")
    .in("id", memberships.map((membership) => membership.company_id))
    .eq("is_active", true);

  if (companyError || !companies) return [];

  return companies.map((company) => ({
    id: company.id,
    display_name: company.display_name,
    role: memberships.find((membership) => membership.company_id === company.id)?.role ?? "viewer"
  }));
}
