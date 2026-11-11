import { WorkspacePage } from "@/components/workspace-page";

export default function SalesPage() {
  return <WorkspacePage eyebrow="Commercial transactions" title="Sales & Proformas" description="Prepare and control commercial offers, quotations and sales documents." capabilities={["Quotation and proforma preparation","Product and customer pricing","Discount and approval controls","15% VAT calculation and presentation","Sales document lifecycle and print views","Transaction-linked direct cost capture"]} />;
}
