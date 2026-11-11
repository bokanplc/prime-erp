import { WorkspacePage } from "@/components/workspace-page";

export default function DocumentsPage() {
  return <WorkspacePage eyebrow="Controlled files" title="Documents" description="A secure home for company documents and transaction attachments." capabilities={["Access-controlled document storage","Transaction attachments","Document version metadata","Search and classification","Download and access audit trail"]} />;
}
