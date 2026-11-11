import { WorkspacePage } from "@/components/workspace-page";

export default function PurchasingPage() {
  return <WorkspacePage eyebrow="Supplier operations" title="Purchasing" description="Organize supplier information, purchase requests, orders and purchase price records." capabilities={["Supplier directory and contacts","Purchase requests","Purchase orders and approval stages","Purchase price capture","Purchase document history","No supplier payment processing"]} />;
}
