import { setActiveCompany } from "@/app/company-actions";
import type { CompanyMembership } from "@/lib/auth/company-context";

export function CompanySwitcher({ companies, activeCompanyId }: {
  companies: CompanyMembership[];
  activeCompanyId: string;
}) {
  return (
    <form action={setActiveCompany} className="company-switcher">
      <label className="sr-only" htmlFor="companyId">Active company</label>
      <select id="companyId" name="companyId" defaultValue={activeCompanyId} aria-label="Active company">
        {companies.map((company) => (
          <option key={company.companyId} value={company.companyId}>{company.displayName}</option>
        ))}
      </select>
      {companies.length > 1 ? <button type="submit">Switch</button> : null}
    </form>
  );
}
