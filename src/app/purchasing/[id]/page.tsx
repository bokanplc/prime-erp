import Link from "next/link";
import { notFound } from "next/navigation";
import { getCompanyContext } from "@/lib/auth/company-context";
import { PrintButton } from "@/app/sales/print-button";

type Props={params:Promise<{id:string}>};
const money=(value:number|null)=>new Intl.NumberFormat("en-ET",{style:"currency",currency:"ETB",minimumFractionDigits:2,maximumFractionDigits:2}).format(value??0);
export const dynamic="force-dynamic";

export default async function PurchaseOrderPage({params}:Props) {
  const {id}=await params;
  const context=await getCompanyContext();
  const companyId=context.active.companyId;
  const {data:order,error}=await context.supabase.from("purchase_orders")
    .select("id,order_number,status,order_date,expected_date,subtotal,vat_treatment,vat_rate_bps,vat_total,grand_total,notes,supplier_id,created_at")
    .eq("id",id).eq("company_id",companyId).maybeSingle();
  if(error||!order)notFound();

  const [{data:supplier},{data:lines}]=await Promise.all([
    context.supabase.from("suppliers").select("legal_name,contact_name,phone,email,address,tax_number").eq("id",order.supplier_id).eq("company_id",companyId).maybeSingle(),
    context.supabase.from("purchase_order_lines").select("description,quantity,unit_of_measure,unit_price,line_net").eq("purchase_order_id",order.id).eq("company_id",companyId).order("created_at")
  ]);
  const vatLabel=order.vat_treatment==="exclusive"?"VAT added to prices":order.vat_treatment==="inclusive"?"VAT included in prices":"No VAT";

  return (
    <main className="print-document">
      <div className="document-toolbar no-print"><Link className="back-link" href="/purchasing">← Back to Purchasing</Link><PrintButton/></div>
      <header className="print-doc-header">
        <div><div className="print-brand-mark">B</div><div className="print-brand-name">BOKAN ERP</div><div className="print-company-name">{context.active.legalName}</div></div>
        <div className="print-doc-title"><div className="eyebrow">{context.active.displayName}</div><h1>PURCHASE ORDER</h1><strong>{order.order_number}</strong><span className="stage-pill">{order.status}</span></div>
      </header>

      <section className="print-doc-meta">
        <div><span>Supplier</span><strong>{supplier?.legal_name??"Supplier"}</strong>{supplier?.contact_name?<p>{supplier.contact_name}</p>:null}{supplier?.address?<p>{supplier.address}</p>:null}{supplier?.phone?<p>{supplier.phone}</p>:null}{supplier?.email?<p>{supplier.email}</p>:null}{supplier?.tax_number?<p>Tax number: {supplier.tax_number}</p>:null}</div>
        <div className="print-date-block"><p><span>Order date</span><strong>{new Date(order.order_date+"T00:00:00").toLocaleDateString()}</strong></p><p><span>Expected delivery</span><strong>{order.expected_date?new Date(order.expected_date+"T00:00:00").toLocaleDateString():"—"}</strong></p><p><span>Currency</span><strong>ETB · Ethiopian Birr</strong></p></div>
      </section>

      <table className="print-lines-table"><thead><tr><th>#</th><th>Description</th><th>Quantity</th><th>Unit</th><th>Unit price</th><th>Line total</th></tr></thead><tbody>
        {(lines??[]).map((line,index)=><tr key={index}><td>{index+1}</td><td>{line.description}</td><td>{Number(line.quantity).toLocaleString("en-ET")}</td><td>{line.unit_of_measure}</td><td>{money(Number(line.unit_price))}</td><td>{money(Number(line.line_net))}</td></tr>)}
      </tbody></table>

      <section className="print-totals">
        <div><span>Subtotal</span><strong>{money(Number(order.subtotal))}</strong></div>
        <div><span>Net before VAT</span><strong>{money(Number(order.grand_total)-Number(order.vat_total))}</strong></div>
        <div><span>{vatLabel} · {order.vat_rate_bps/100}%</span><strong>{money(Number(order.vat_total))}</strong></div>
        <div className="print-grand-total"><span>Order total</span><strong>{money(Number(order.grand_total))}</strong></div>
      </section>

      {order.notes?<section className="print-terms"><h2>Order notes and terms</h2><p>{order.notes}</p></section>:null}
      <footer className="print-doc-footer"><span>Prepared using BOKAN ERP · {context.active.displayName}</span><span>This purchase order is not a goods receipt, supplier payment or accounting entry.</span></footer>
    </main>
  );
}
