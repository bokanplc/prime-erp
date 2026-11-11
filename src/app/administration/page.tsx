import Link from "next/link";
import { redirect } from "next/navigation";
import { getCompanyContext } from "@/lib/auth/company-context";
import { addCompanyMember, updateCompanyMember } from "./actions";

export const dynamic="force-dynamic";
type Props={searchParams:Promise<{error?:string;added?:string;updated?:string}>};
type CompanyMember={user_id:string;email:string|null;role:string;is_active:boolean;created_at:string};

const errorMessages:Record<string,string>={
  email:"Enter a valid email address.",
  access:"Only a company owner or admin can manage memberships.",
  role:"Your role cannot assign that permission level.",
  "user-not-found":"No existing V7 Auth account matches that email. Invite or create the account in Supabase Auth first.",
  "already-member":"That account already has a membership in this company.",
  add:"The membership could not be added. Check company access and try again.",
  update:"The membership could not be updated. Check your permission level."
};

export default async function AdministrationPage({searchParams}:Props) {
  const context=await getCompanyContext();
  if(!["owner","admin","manager"].includes(context.active.role))redirect("/");
  const params=await searchParams;
  const {data:members,error}=await context.supabase.rpc("list_company_members",{target_company_id:context.active.companyId});
  const memberRows=(members??[]) as CompanyMember[];
  const canManage=["owner","admin"].includes(context.active.role);
  const canAssignElevated=context.active.role==="owner";

  return (
    <main className="workspace-page">
      <Link className="back-link" href="/">← BOKAN ERP overview</Link>
      <div className="eyebrow">Access governance · {context.active.displayName}</div>
      <h1>Administration</h1>
      <p className="workspace-description">Manage access to this company. Memberships are separate for Prime Investment Group and BlackRock Investment PLC; changing one company does not grant access to the other.</p>

      {params.error?<div className="workspace-notice"><strong>Action not completed.</strong>{errorMessages[params.error]??"Please check your access and try again."}</div>:null}
      {params.added?<div className="workspace-success" role="status">Company membership added.</div>:null}
      {params.updated?<div className="workspace-success" role="status">Membership updated.</div>:null}

      <section className="workspace-panel">
        <div className="workspace-panel-heading"><div><h2>Company members</h2><p>Existing V7 accounts and their active role in this company.</p></div><span className="record-count">{memberRows.length} members</span></div>
        {error?<div className="workspace-notice"><strong>Membership list unavailable.</strong>The member directory function or your company permission needs attention.</div>:memberRows.length?<div className="table-scroll"><table className="records-table"><thead><tr><th>Account</th><th>Role</th><th>Status</th><th>Member since</th><th>Manage</th></tr></thead><tbody>{memberRows.map(member=>{
          const isSelf=member.user_id===context.user.id;
          const canEdit=canManage&&!isSelf&&(context.active.role==="owner"||!["owner","admin"].includes(member.role));
          return <tr key={member.user_id}><td><strong>{member.email||"Email unavailable"}</strong>{isSelf?<small>Your current account</small>:null}</td><td>{member.role}</td><td><span className="stage-pill">{member.is_active?"Active":"Inactive"}</span></td><td>{new Date(member.created_at).toLocaleDateString()}</td><td>{canEdit?<div className="member-controls">
            <form action={updateCompanyMember} className="inline-stage-form"><input type="hidden" name="userId" value={member.user_id}/><input type="hidden" name="isActive" value={String(member.is_active)}/><select name="role" defaultValue={member.role} aria-label={`Role for ${member.email}`}>{["manager","sales","purchasing","operations","data_entry","viewer",...(canAssignElevated?["admin","owner"]:[])].map(role=><option key={role} value={role}>{role}</option>)}</select><button type="submit">Save role</button></form>
            <form action={updateCompanyMember}><input type="hidden" name="userId" value={member.user_id}/><input type="hidden" name="role" value={member.role}/><input type="hidden" name="isActive" value={String(!member.is_active)}/><button className="member-toggle" type="submit">{member.is_active?"Deactivate":"Reactivate"}</button></form>
          </div>:isSelf?"You": "Owner / admin only"}</td></tr>;
        })}</tbody></table></div>:<div className="workspace-empty"><div className="empty-mark">♙</div><h2>No memberships found</h2><p>The first company owner must be provisioned during secure initial setup. No sample employees or roles have been created.</p></div>}
      </section>

      {canManage?<section className="workspace-panel"><h2>Add an existing V7 account</h2><p className="panel-hint">The account must already exist in V7 Supabase Authentication. This grants membership in the active company only; it does not send an invitation email.</p><form action={addCompanyMember} className="record-form"><div className="form-grid">
        <label>Existing account email <span>*</span><input name="email" type="email" required maxLength={254} placeholder="employee@company.com"/></label>
        <label>Company role <span>*</span><select name="role" defaultValue="sales"><option value="sales">Sales</option><option value="data_entry">Data entry</option><option value="purchasing">Purchasing</option><option value="operations">Operations</option><option value="viewer">Viewer</option><option value="manager">Manager</option>{canAssignElevated?<><option value="admin">Admin</option><option value="owner">Owner</option></>:null}</select></label>
      </div><div className="form-actions"><button type="submit">Grant company access</button></div></form></section>:null}

      <section className="workspace-panel"><h2>Role boundaries</h2><div className="role-boundary-list">
        <p><strong>Owner / Admin</strong><span>Company access governance, configuration and approvals. Only the owner can assign another owner or admin.</span></p>
        <p><strong>Manager</strong><span>Operational oversight and commercial approvals; can view company membership but cannot assign roles.</span></p>
        <p><strong>Sales</strong><span>CRM, quotations, customer pricing, direct sales costs and delivery coordination.</span></p>
        <p><strong>Purchasing</strong><span>Suppliers, product purchase prices, purchase requests, purchase orders and direct purchase costs.</span></p>
        <p><strong>Data entry</strong><span>Record approved sales and purchasing source data, but cannot approve commercial documents.</span></p>
        <p><strong>Viewer</strong><span>Read-only company access.</span></p>
      </div></section>
    </main>
  );
}
