import Link from "next/link";
import { notFound } from "next/navigation";
import { getCompanyContext } from "@/lib/auth/company-context";
import { PrintButton } from "../print-button";

type Props = { params: Promise<{ id: string }> };
const money = (value: number) => new Intl.NumberFormat("en-ET", {
  minimumFractionDigits: 2, maximumFractionDigits: 2
}).format(Number.isFinite(value) ? value : 0);
const dateText = (value: string) => new Date(value + "T00:00:00").toLocaleDateString("en-US");

export const dynamic = "force-dynamic";

export default async function SalesDocumentPage({ params }: Props) {
  const { id } = await params;
  const context = await getCompanyContext();
  const companyId = context.active.companyId;
  const { data: document, error } = await context.supabase.from("sales_documents")
    .select("id,document_number,document_type,status,issue_date,valid_until,subtotal,discount_total,vat_treatment,vat_rate_bps,vat_total,grand_total,terms,customer_id,created_at")
    .eq("id", id).eq("company_id", companyId).maybeSingle();
  if (error || !document) notFound();

  const [{ data: customer }, { data: lines }] = await Promise.all([
    context.supabase.from("customers").select("legal_name,display_name,contact_name,email,phone,address,tax_id,tax_number").eq("id", document.customer_id).eq("company_id", companyId).maybeSingle(),
    context.supabase.from("sales_document_lines").select("description,quantity,unit_of_measure,unit_price,discount_amount,line_net").eq("sales_document_id", document.id).eq("company_id", companyId).order("created_at")
  ]);

  const rate = Number(document.vat_rate_bps ?? context.active.vatRateBps) / 10000;
  const isInclusive = document.vat_treatment === "inclusive";
  const hasVat = document.vat_treatment !== "none";
  const title = document.document_type === "quotation" ? "QUOTATION" : document.document_type === "sales_order" ? "SALES ORDER" : "PROFORMA INVOICE";
  const beforeVatTotal = Number(document.grand_total) - Number(document.vat_total);
  const customerTin = customer?.tax_id || customer?.tax_number;
  const terms = document.terms?.trim() || "Price is valid for 3 days\nPayment is 100% upfront\nDelivery time: 3–5 business days\nTransportation is included";

  return (
    <main className="classic-proforma">
      <div className="classic-toolbar no-print">
        <Link className="back-link" href="/sales">← Back to Sales</Link>
        <PrintButton />
      </div>

      <header className="classic-invoice-header">
        <div className="classic-company">
          <h2>{context.active.legalName || "BlackRock Investment Plc"}</h2>
          <strong>TIN: 0093053349</strong>
          <span>Meskel Flower, Addis Ababa, Ethiopia</span>
          <span>Tel: 978 23 48 20</span>
        </div>
        <div className="classic-invoice-id">
          <h1>{title}</h1>
          <span>No: {document.document_number}</span>
          <span>Date: {dateText(document.issue_date)}</span>
        </div>
      </header>

      <section className="classic-bill-to">
        <strong>Bill To: {customer?.display_name || customer?.legal_name || "Customer"}</strong>
        {customerTin ? <span>Customer TIN: {customerTin}</span> : null}
        {customer?.address ? <span>{customer.address}</span> : null}
        {customer?.phone ? <span>Tel: {customer.phone}</span> : null}
        {customer?.contact_name ? <span>Contact Person: {customer.contact_name}</span> : null}
      </section>

      <table className="classic-items">
        <thead><tr>
          <th>#</th><th>ITEM</th><th>DESCRIPTION</th><th>QTY</th>
          <th>BEFORE VAT</th><th>VAT</th><th>UNIT PRICE INCL. VAT</th><th>TOTAL</th>
        </tr></thead>
        <tbody>
          {(lines ?? []).map((line, index) => {
            const quantity = Number(line.quantity) || 0;
            const lineAmount = Number(line.line_net) || 0;
            const netLine = isInclusive && hasVat ? lineAmount / (1 + rate) : lineAmount;
            const netUnit = quantity ? netLine / quantity : 0;
            const vatUnit = hasVat ? netUnit * rate : 0;
            const grossUnit = netUnit + vatUnit;
            return <tr key={index}>
              <td>{index + 1}</td>
              <td>{line.description}</td>
              <td>{line.unit_of_measure || "—"}</td>
              <td>{quantity.toLocaleString("en-ET")}</td>
              <td>{money(netUnit)}</td>
              <td>{money(vatUnit)}</td>
              <td>{money(grossUnit)}</td>
              <td>{money(grossUnit * quantity)}</td>
            </tr>;
          })}
        </tbody>
      </table>

      <section className="classic-lower">
        <div className="classic-terms">
          <h2>TERMS &amp; CONDITIONS</h2>
          <ul>{terms.split(/\r?\n/).filter(Boolean).map((term, index) => <li key={index}>{term.replace(/^[-•]\s*/, "")}</li>)}</ul>
        </div>
        <div className="classic-totals">
          <div><span>Subtotal Before VAT</span><strong>ETB {money(beforeVatTotal)}</strong></div>
          <div><span>Total VAT ({(Number(document.vat_rate_bps ?? context.active.vatRateBps) / 100).toLocaleString("en-ET") }%)</span><strong>ETB {money(Number(document.vat_total))}</strong></div>
          {Number(document.discount_total) > 0 ? <div><span>Discount</span><strong>− ETB {money(Number(document.discount_total))}</strong></div> : null}
          <div className="classic-grand"><span>Grand Total</span><strong>ETB {money(Number(document.grand_total))}</strong></div>
        </div>
      </section>

      <footer className="classic-signatures">
        <span>Prepared by: ____________________</span>
        <span>Authorized signature: ____________________</span>
      </footer>
    </main>
  );
}
