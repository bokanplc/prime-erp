import Link from "next/link";
import { getCompanyContext } from "@/lib/auth/company-context";
import { markAllNotificationsRead, markNotificationRead } from "./actions";

export const dynamic="force-dynamic";

type Notice={id:string;notification_type:string;title:string;body:string;href:string;read_at:string|null;created_at:string};

export default async function NotificationsPage() {
  const context=await getCompanyContext();
  const {data,error}=await context.supabase.from("notifications")
    .select("id,notification_type,title,body,href,read_at,created_at")
    .eq("company_id",context.active.companyId)
    .order("created_at",{ascending:false})
    .limit(100);
  const notices=(data??[]) as Notice[];
  const unread=notices.filter(item=>!item.read_at).length;

  return (
    <main className="workspace-page">
      <Link className="back-link" href="/">← BOKAN ERP overview</Link>
      <div className="eyebrow">Team updates · {context.active.displayName}</div>
      <div className="notification-page-heading"><div><h1>Notifications</h1><p className="workspace-description">Approval updates and purchasing workflow alerts for your account in this company.</p></div>{unread?<form action={markAllNotificationsRead}><button type="submit" className="member-toggle">Mark all read</button></form>:null}</div>
      <section className="workspace-panel">
        <div className="workspace-panel-heading"><div><h2>Your notifications</h2><p>Private to your account · latest 100</p></div><span className="record-count">{unread} unread</span></div>
        {error?<div className="workspace-notice"><strong>Notifications unavailable.</strong>Check your company membership and try again.</div>:notices.length?<div className="notification-list">{notices.map(notice=><article className={`notification-item ${notice.read_at?"is-read":"is-unread"}`} key={notice.id}><div className="notification-mark">{notice.read_at?"✓":"●"}</div><div className="notification-copy"><div className="notification-meta"><span className="stage-pill">{notice.notification_type.replaceAll("_"," ")}</span><time>{new Date(notice.created_at).toLocaleString()}</time></div><strong>{notice.title}</strong><p>{notice.body}</p><Link className="document-link" href={notice.href}>Open related workspace →</Link></div>{!notice.read_at?<form action={markNotificationRead}><input type="hidden" name="notificationId" value={notice.id}/><button className="member-toggle" type="submit">Mark read</button></form>:null}</article>)}</div>:<div className="workspace-empty"><div className="empty-mark">♧</div><h2>You’re all caught up</h2><p>New approval requests and workflow updates will appear here.</p></div>}
      </section>
      <p className="panel-hint">Notifications are in-app only. They do not send email or SMS messages.</p>
    </main>
  );
}
