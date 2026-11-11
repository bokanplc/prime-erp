"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { getCompanyContext } from "@/lib/auth/company-context";

const assignableRoles = ["manager","sales","purchasing","operations","data_entry","viewer"];

export async function addCompanyMember(formData: FormData): Promise<void> {
  const email=String(formData.get("email")??"").trim().toLowerCase();
  const role=String(formData.get("role")??"sales");
  if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))redirect("/administration?error=email");

  const context=await getCompanyContext();
  if(!["owner","admin"].includes(context.active.role))redirect("/administration?error=access");
  if(context.active.role==="admin"&&![...assignableRoles,"admin"].includes(role))redirect("/administration?error=role");
  if(context.active.role==="owner"&&![...assignableRoles,"owner","admin"].includes(role))redirect("/administration?error=role");

  const {data:userId,error:lookupError}=await context.supabase.rpc("find_company_auth_user",{
    target_company_id:context.active.companyId,
    target_email:email
  });
  if(lookupError||!userId)redirect("/administration?error=user-not-found");

  const {error}=await context.supabase.from("company_memberships").insert({
    company_id:context.active.companyId,
    user_id:userId,
    role,
    is_active:true
  });
  if(error)redirect(error.code==="23505"?"/administration?error=already-member":"/administration?error=add");
  revalidatePath("/administration");
  redirect("/administration?added=1");
}

export async function updateCompanyMember(formData: FormData): Promise<void> {
  const userId=String(formData.get("userId")??"").trim();
  const role=String(formData.get("role")??"");
  const isActive=String(formData.get("isActive")??"")!=="false";
  if(!userId||![...assignableRoles,"owner","admin"].includes(role))return;

  const context=await getCompanyContext();
  if(!["owner","admin"].includes(context.active.role))return;
  if(context.active.role==="admin"&&![...assignableRoles,"admin"].includes(role))return;

  const {error}=await context.supabase.from("company_memberships")
    .update({role,is_active:isActive})
    .eq("company_id",context.active.companyId)
    .eq("user_id",userId);
  if(error)redirect("/administration?error=update");
  revalidatePath("/administration");
  redirect("/administration?updated=1");
}

export async function updateCompanySettings(formData: FormData): Promise<void> {
  const legalName=String(formData.get("legalName")??"").trim();
  const displayName=String(formData.get("displayName")??"").trim();
  const vatRatePercent=Number(formData.get("vatRatePercent"));
  if(legalName.length<2||legalName.length>200||displayName.length<2||displayName.length>120||!Number.isFinite(vatRatePercent)||vatRatePercent<0||vatRatePercent>100)return;

  const context=await getCompanyContext();
  if(!["owner","admin"].includes(context.active.role))return;

  const {error}=await context.supabase.from("companies")
    .update({legal_name:legalName,display_name:displayName,vat_rate_bps:Math.round(vatRatePercent*100)})
    .eq("id",context.active.companyId);
  if(error)redirect("/administration?error=settings");
  revalidatePath("/");
  revalidatePath("/administration");
  revalidatePath("/sales");
  revalidatePath("/purchasing");
  revalidatePath("/profitability");
  redirect("/administration?settings=updated");
}
