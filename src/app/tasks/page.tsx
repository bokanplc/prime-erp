import { WorkspacePage } from "@/components/workspace-page";

export default function TasksPage() {
  return <WorkspacePage eyebrow="Team productivity" title="Tasks & Reminders" description="Keep customer commitments and internal follow-ups visible and accountable." capabilities={["Personal and team task lists","Due dates and reminders","CRM-linked follow-ups","Assignment and completion tracking","Overdue activity review"]} />;
}
