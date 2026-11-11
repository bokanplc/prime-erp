import { WorkspacePage } from "@/components/workspace-page";

export default function ProfitabilityPage() {
  return <WorkspacePage eyebrow="Commercial insight" title="Profitability" description="Measure product and transaction profitability without introducing a general ledger or payment system." capabilities={["Landed gross profit","Profit after direct sales costs","Transportation cost allocation","Loading cost allocation","Miscellaneous transaction cost allocation","Margin analysis and exception review"]} />;
}
