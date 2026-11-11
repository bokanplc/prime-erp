import { WorkspacePage } from "@/components/workspace-page";

export default function AdministrationPage() {
  return <WorkspacePage eyebrow="Access and governance" title="Administration" description="Control company setup, user access and role permissions after the secure bootstrap process is approved." capabilities={["Company and workspace setup","User invitations and membership","Role-based access control","Security and audit review","System configuration"]} />;
}
