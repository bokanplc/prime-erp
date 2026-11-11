import { WorkspacePage } from "@/components/workspace-page";

export default function CRMPage() {
  return <WorkspacePage eyebrow="Customer relationships" title="CRM & Customers" description="Manage the full customer relationship lifecycle and sales-team follow-up activity." capabilities={["Customer and contact directory","Lead capture and pipeline stages","Calls, visits and meeting notes","Follow-up reminders and tasks","Customer interaction timeline","Salesperson activity and performance"]} />;
}
