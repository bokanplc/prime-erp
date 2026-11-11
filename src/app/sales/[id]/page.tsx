import Link from "next/link";
import { notFound } from "next/navigation";
import { getCompanyContext } from "@/lib/auth/company-context";
import { PrintButton } from "../print-button";

type Props={params:Promise<{id:string}>};
const money=(value:number|null)=>new Intl.NumberFormat("en-ET",{style:"currency",currency:"ETB",minimumFractionDigits:2,maximumFractionDigits:2}).format(value??0);

export const dynamic="force-dynamic";

export default async function SalesDocumentPage({params}:Props) {
  const {id}=await params;
  const context=await getCompanyContext();
  const companyId=context.active.companyId;
  const {data:document,error}=await context.supabase.from("sales_documents")
    .select("id,document_number,document_type,status,issue_date,valid_until,subtotal,discount_total,vat_treatment,vat_rate_bps,vat_total,grand_total,terms,customer_id,created_at")
    .eq("id",id).eq("company_id",companyId).maybeSingle();
  if(error||!document)notFound();

  const [{data:customer},{data:lines}]=await Promise.all([
    context.supabase.from("customers").select("legal_name,display_name,contact_name,email,phone,address,tax_id,tax_number").eq("id",document.customer_id).eq("company_id",companyId).maybeSingle(),
    context.supabase.from("sales_document_lines").select("description,quantity,unit_of_measure,unit_price,discount_amount,line_net,landed_unit_cost").eq("sales_document_id",document.id).eq("company_id",companyId).order("created_at")
  ]);
  const vatLabel=document.vat_treatment==="exclusive"?"VAT added to prices":document.vat_treatment==="inclusive"?"VAT included in prices":"No VAT";
  const title=document.document_type==="quotation"?"QUOTATION":document.document_type==="sales_order"?"SALES ORDER":"PROFORMA INVOICE";

  return (
    <main className="print-document">
      <div className="document-toolbar no-print"><Link className="back-link" href="/sales">← Back to Sales</Link><PrintButton/></div>
      <header className="print-doc-header">
        <div><div className="print-brand-mark">B</div><div className="print-brand-name">BOKAN ERP</div><div className="print-company-name">{context.active.legalName}</div></div>
        <div className="print-doc-title"><div className="eyebrow">{context.active.displayName}</div><h1>{title}</h1><strong>{document.document_number}</strong><span className="stage-pill">{document.status}</span></div>
      </header>

      <section className="print-doc-meta">
        <div><span>Bill to / Customer</span><strong>{customer?.display_name||customer?.legal_name||"Customer"}</strong><p>{customer?.legal_name&&customer.display_name!==customer.legal_name?customer.legal_name:null}</p>{customer?.contact_name?<p>{customer.contact_name}</p>:null}{customer?.address?<p>{customer.address}</p>:null}{customer?.phone?<p>{customer.phone}</p>:null}{customer?.email?<p>{customer.email}</p>:null}{(customer?.tax_id||customer?.tax_number)?<p>Tax ID: {customer.tax_id||customer.tax_number}</p>:null}</div>
        <div className="print-date-block"><p><span>Issue date</span><strong>{new Date(document.issue_date+"T00:00:00").toLocaleDateString()}</strong></p><p><span>Valid until</span><strong>{document.valid_until?new Date(document.valid_until+"T00:00:00").toLocaleDateString():"—"}</strong></p><p><span>Currency</span><strong>ETB · Ethiopian Birr</strong></p></div>
      </section>

      <table className="print-lines-table"><thead><tr><th>#</th><th>Description</th><th>Quantity</th><th>Unit</th><th>Unit price</th><th>Discount</th><th>Line total</th></tr></thead><tbody>
        {(lines??[]).map((line,index)=><tr key={index}><td>{index+1}</td><td>{line.description}</td><td>{Number(line.quantity).toLocaleString("en-ET")}</td><td>{line.unit_of_measure}</td><td>{money(Number(line.unit_price))}</td><td>{money(Number(line.discount_amount))}</td><td>{money(Number(line.line_net))}</td></tr>)}
      </tbody></table>

      <section className="print-totals">
        <div><span>Subtotal</span><strong>{money(Number(document.subtotal))}</strong></div>
        <div><span>Discount</span><strong>− {money(Number(document.discount_total))}</strong></div>
        <div><span>Net before VAT</span><strong>{money(Number(document.grand_total)-Number(document.vat_total))}</strong></div>
        <div><span>{vatLabel} · {document.vat_rate_bps/100}%</span><strong>{money(Number(document.vat_total))}</strong></div>
        <div className="print-grand-total"><span>Grand total</span><strong>{money(Number(document.grand_total))}</strong></div>
      </section>

      {document.terms?<section className="print-terms"><h2>Terms and conditions</h2><p>{document.terms}</p></section>:null}
      <footer className="print-doc-footer"><span>Prepared using BOKAN ERP · {context.active.displayName}</span><span>This document is a commercial offer, not a receipt or payment confirmation.</span></footer>
    </main>
  );
}
