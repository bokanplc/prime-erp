import Link from "next/link";
import { getCompanyContext } from "@/lib/auth/company-context";

export const dynamic = "force-dynamic";
const money = (value: number) => new Intl.NumberFormat("en-ET",{style:"currency",currency:"ETB",minimumFractionDigits:2,maximumFractionDigits:2}).format(value);
const round = (value:number) => Math.round((value+Number.EPSILON)*100)/100;

function normalizedCost(amount:number, treatment:string, recoverable:boolean) {
  if (treatment === "none") return amount;
  if (treatment === "inclusive") return recoverable ? amount / 1.15 : amount;
  return recoverable ? amount : amount * 1.15;
}

export default async function ProfitabilityPage() {
  const context = await getCompanyContext();
  const companyId = context.active.companyId;
  const [{data:documents},{data:lines},{data:salesCosts},{data:purchaseOrders},{data:purchaseCosts}] = await Promise.all([
    context.supabase.from("sales_documents").select("id,document_number,document_type,status,issue_date,grand_total,vat_total").eq("company_id",companyId).in("status",["approved","sent","accepted"]).order("issue_date",{ascending:false}).limit(500),
    context.supabase.from("sales_document_lines").select("id,sales_document_id,description,quantity,unit_of_measure,line_net,landed_unit_cost,landed_cost_reference").eq("company_id",companyId).limit(5000),
    context.supabase.from("direct_costs").select("id,sales_document_id,category,description,amount,vat_treatment,recoverable_vat,incurred_on").eq("company_id",companyId).not("sales_document_id","is",null).limit(3000),
    context.supabase.from("purchase_orders").select("id,order_number,status,order_date,subtotal,vat_total,grand_total").eq("company_id",companyId).in("status",["approved","sent","accepted"]).order("order_date",{ascending:false}).limit(500),
    context.supabase.from("direct_costs").select("id,purchase_order_id,category,description,amount,vat_treatment,recoverable_vat,incurred_on").eq("company_id",companyId).not("purchase_order_id","is",null).limit(3000)
  ]);

  const lineMap = new Map<string, NonNullable<typeof lines>[number][]>();
  for(const line of lines??[]){const rows=lineMap.get(line.sales_document_id)??[];rows.push(line);lineMap.set(line.sales_document_id,rows);}
  const salesCostMap = new Map<string, NonNullable<typeof salesCosts>[number][]>();
  for(const cost of salesCosts??[]){if(!cost.sales_document_id)continue;const rows=salesCostMap.get(cost.sales_document_id)??[];rows.push(cost);salesCostMap.set(cost.sales_document_id,rows);}

  const results=(documents??[]).map(doc=>{
    const docLines=lineMap.get(doc.id)??[];
    const lineBase=docLines.reduce((sum,line)=>sum+Number(line.line_net),0);
    const revenue=round(Number(doc.grand_total)-Number(doc.vat_total));
    const ratio=lineBase>0?revenue/lineBase:0;
    const allCosted=docLines.length>0&&docLines.every(line=>line.landed_unit_cost!==null);
    const landedCost=round(docLines.reduce((sum,line)=>sum+(line.landed_unit_cost===null?0:Number(line.quantity)*Number(line.landed_unit_cost)),0));
    const grossProfit=allCosted?round(revenue-landedCost):null;
    const costs=salesCostMap.get(doc.id)??[];
    const directCosts=round(costs.reduce((sum,cost)=>sum+normalizedCost(Number(cost.amount),cost.vat_treatment,cost.recoverable_vat),0));
    const profitAfter=grossProfit===null?null:round(grossProfit-directCosts);
    return {id:doc.id,number:doc.document_number,type:doc.document_type,date:doc.issue_date,status:doc.status,lineCount:docLines.length,revenue,landedCost,grossProfit,directCosts,profitAfter,missing:docLines.filter(line=>line.landed_unit_cost===null).length,margin:grossProfit!==null&&revenue>0?grossProfit/revenue*100:null};
  });

  const totalRevenue=round(results.reduce((sum,row)=>sum+row.revenue,0));
  const costed=results.filter(row=>row.grossProfit!==null);
  const grossProfit=round(costed.reduce((sum,row)=>sum+(row.grossProfit??0),0));
  const directCosts=round(costed.reduce((sum,row)=>sum+row.directCosts,0));
  const profitAfter=round(grossProfit-directCosts);
  const uncostedLines=results.reduce((sum,row)=>sum+row.missing,0);
  const coverage=results.length?Math.round(costed.length/results.length*100):0;
  const purchaseCostTotal=round((purchaseCosts??[]).reduce((sum,cost)=>sum+normalizedCost(Number(cost.amount),cost.vat_treatment,cost.recoverable_vat),0));
  const purchaseOrderValue=round((purchaseOrders??[]).reduce((sum,order)=>sum+Number(order.grand_total),0));

  return (
    <main className="workspace-page">
      <Link className="back-link" href="/">← BOKAN ERP overview</Link>
      <div className="eyebrow">Commercial insight · {context.active.displayName}</div>
      <h1>Profitability</h1>
      <p className="workspace-description">Commercial margin analysis from approved sales documents and manually verified landed unit costs. Revenue excludes output VAT; direct sales costs are deducted separately. No stock valuation, accounting postings or payment records are created.</p>

      <section className="workspace-panel">
        <div className="workspace-panel-heading"><div><h2>Sales profitability summary</h2><p>Approved, sent and accepted sales documents only.</p></div><span className="record-count">{results.length} documents</span></div>
        <div className="profit-kpi-grid">
          <article className="profit-kpi"><span>Revenue excluding VAT</span><strong>{money(totalRevenue)}</strong><small>All included sales documents</small></article>
          <article className="profit-kpi"><span>Landed gross profit</span><strong>{costed.length?money(grossProfit):"—"}</strong><small>{costed.length} of {results.length} documents fully costed</small></article>
          <article className="profit-kpi"><span>Direct sales costs</span><strong>{money(directCosts)}</strong><small>Only fully costed sales documents</small></article>
          <article className="profit-kpi"><span>Profit after direct costs</span><strong>{costed.length?money(profitAfter):"—"}</strong><small>After transportation, loading and miscellaneous</small></article>
        </div>
        {uncostedLines>0?<div className="workspace-notice"><strong>{uncostedLines} sales line(s) are missing a verified landed unit cost.</strong>Complete landed cost data on the sales document before treating the gross profit and margin totals as complete. Incomplete documents are excluded from profit totals.</div>:null}
        {results.length?<div className="table-scroll"><table className="records-table"><thead><tr><th>Document</th><th>Date</th><th>Net revenue</th><th>Landed cost</th><th>Gross profit</th><th>Direct sales costs</th><th>Profit after costs</th><th>Margin</th><th>Cost coverage</th></tr></thead><tbody>{results.map(row=><tr key={row.id}><td><strong>{row.number}</strong><small>{row.type.replace("_"," ")}</small></td><td>{new Date(row.date+"T00:00:00").toLocaleDateString()}</td><td>{money(row.revenue)}</td><td>{row.grossProfit===null?"Incomplete":money(row.landedCost)}</td><td>{row.grossProfit===null?"—":money(row.grossProfit)}</td><td>{money(row.directCosts)}</td><td>{row.profitAfter===null?"—":money(row.profitAfter)}</td><td>{row.margin===null?"—":row.margin.toFixed(1)+"%"}</td><td>{row.grossProfit===null?<span className="stage-pill">Missing {row.missing} cost(s)</span>:<span className="stage-pill">Complete</span>}</td></tr>)}</tbody></table></div>:<div className="workspace-empty"><div className="empty-mark">∑</div><h2>No approved sales to analyze</h2><p>Approved sales documents will appear here. Add a verified landed unit cost to each sales line to calculate landed gross profit.</p></div>}
      </section>

      <section className="workspace-panel">
        <h2>Purchase-side cost visibility</h2>
        <p className="panel-hint">These purchase commitments and costs are shown separately. They are not silently allocated to sales or inventory. Enter the verified landed unit cost on the related sales line when calculating gross profit.</p>
        <div className="profit-kpi-grid profit-kpi-grid-two">
          <article className="profit-kpi"><span>Approved purchase order value</span><strong>{money(purchaseOrderValue)}</strong><small>{purchaseOrders?.length??0} approved purchase orders</small></article>
          <article className="profit-kpi"><span>Direct purchase costs</span><strong>{money(purchaseCostTotal)}</strong><small>Transportation, loading and miscellaneous</small></article>
        </div>
        {purchaseOrders?.length?<div className="table-scroll"><table className="records-table"><thead><tr><th>Purchase order</th><th>Date</th><th>Order value</th><th>Direct costs</th><th>Status</th></tr></thead><tbody>{purchaseOrders.map(order=>{const orderCosts=(purchaseCosts??[]).filter(c=>c.purchase_order_id===order.id).reduce((sum,c)=>sum+normalizedCost(Number(c.amount),c.vat_treatment,c.recoverable_vat),0);return <tr key={order.id}><td><strong>{order.order_number}</strong></td><td>{new Date(order.order_date+"T00:00:00").toLocaleDateString()}</td><td>{money(Number(order.grand_total))}</td><td>{money(orderCosts)}</td><td><span className="stage-pill">{order.status}</span></td></tr>})}</tbody></table></div>:<div className="workspace-empty"><h2>No approved purchase orders</h2><p>Approved purchase commitments and direct purchase costs will be listed here.</p></div>}
      </section>
      <p className="profit-footnote">Margin coverage: {coverage}% of approved sales documents have complete landed cost data. Recoverable input VAT is excluded from cost only when explicitly marked recoverable; non-recoverable VAT remains in cost. These are management calculations, not Peachtree accounting entries.</p>
    </main>
  );
}
