import { WorkspacePage } from "@/components/workspace-page";

export default function ReportsPage() {
  return <WorkspacePage eyebrow="Management information" title="Reports" description="Management views based only on verified V7 records." capabilities={["Sales activity and document summaries","CRM pipeline health","Landed gross profit and net commercial margin","Direct cost analysis","Salesperson performance","Exportable management reports"]} />;
}
