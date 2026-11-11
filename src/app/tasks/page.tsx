import Link from "next/link";
import { getCompanyContext } from "@/lib/auth/company-context";
import { createTask, updateTaskStatus } from "./actions";

export const dynamic = "force-dynamic";

export default async function TasksPage() {
  const context = await getCompanyContext();
  const companyId = context.active.companyId;
  const [{ data: tasks, error }, { data: customers }, { data: leads }] = await Promise.all([
    context.supabase.from("tasks")
      .select("id, title, details, status, due_at, created_at")
      .eq("company_id", companyId)
      .order("due_at", { ascending: true, nullsFirst: false })
      .order("created_at", { ascending: false })
      .limit(100),
    context.supabase.from("customers").select("id, display_name, legal_name").eq("company_id", companyId).order("display_name").limit(200),
    context.supabase.from("crm_leads").select("id, title").eq("company_id", companyId).order("created_at", { ascending: false }).limit(200)
  ]);

  const canWrite = ["owner", "admin", "manager", "sales", "purchasing", "operations", "data_entry"].includes(context.active.role);

  return (
    <main className="workspace-page">
      <Link className="back-link" href="/">← BOKAN ERP overview</Link>
      <div className="eyebrow">Team productivity · {context.active.displayName}</div>
      <h1>Tasks & Reminders</h1>
      <p className="workspace-description">Keep customer commitments, calls, visits and internal follow-ups visible and accountable.</p>

      {canWrite ? <section className="workspace-panel">
        <h2>Create a task or reminder</h2>
        <p className="panel-hint">Tasks are assigned to your account and remain private to this company.</p>
        <form action={createTask} className="record-form">
          <div className="form-grid">
            <label>Task / reminder <span>*</span><input name="title" required minLength={2} maxLength={180} /></label>
            <label>Due date<input name="dueDate" type="date" /></label>
            <label>Customer<select name="customerId" defaultValue=""><option value="">No customer link</option>{(customers ?? []).map(c => <option key={c.id} value={c.id}>{c.display_name || c.legal_name}</option>)}</select></label>
            <label>Lead<select name="leadId" defaultValue=""><option value="">No lead link</option>{(leads ?? []).map(l => <option key={l.id} value={l.id}>{l.title}</option>)}</select></label>
            <label className="form-wide">Details<textarea name="details" rows={2} maxLength={3000} /></label>
          </div>
          <div className="form-actions"><button type="submit">Save task</button></div>
        </form>
      </section> : null}

      <section className="workspace-panel">
        <div className="workspace-panel-heading"><div><h2>Team task list</h2><p>Open tasks, due dates and completion status for the active company.</p></div><span className="record-count">{tasks?.length ?? 0} tasks</span></div>
        {error ? <div className="workspace-notice"><strong>Tasks are unavailable.</strong>Check the V7 schema and your company access.</div> : tasks?.length ? (
          <div className="task-list">{tasks.map(task => <article className="task-item" key={task.id}>
            <div className="task-copy"><strong>{task.title}</strong><p>{task.details || "No additional details"}</p><time>{task.due_at ? `Due ${new Date(task.due_at).toLocaleDateString()}` : "No due date"}</time></div>
            <div className="task-controls"><span className={`stage-pill task-${task.status}`}>{task.status.replace("_", " ")}</span>{canWrite ? <form action={updateTaskStatus} className="inline-stage-form"><input type="hidden" name="taskId" value={task.id} /><select name="status" defaultValue={task.status} aria-label={`Status for ${task.title}`}><option value="open">Open</option><option value="in_progress">In progress</option><option value="completed">Completed</option><option value="cancelled">Cancelled</option></select><button type="submit">Update</button></form> : null}</div>
          </article>)}</div>
        ) : <div className="workspace-empty"><div className="empty-mark">◷</div><h2>No tasks or reminders</h2><p>New reminders from CRM and tasks created by your team will appear here.</p></div>}
      </section>
    </main>
  );
}
