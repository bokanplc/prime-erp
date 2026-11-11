import { WorkspacePage } from "@/components/workspace-page";

export default function LogisticsPage() {
  return <WorkspacePage eyebrow="Delivery operations" title="Logistics & Delivery" description="Coordinate delivery commitments, dispatch progress and delivery exceptions." capabilities={["Delivery planning and scheduling","Dispatch milestones","Transport coordination","Delivery confirmation and evidence","Delay and exception tracking"]} />;
}
