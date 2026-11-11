import { NextResponse, type NextRequest } from "next/server";
import { getSupabasePublicEnv } from "@/lib/supabase/env";
import { updateSession } from "@/lib/supabase/update-session";

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  if (!getSupabasePublicEnv()) {
    if (pathname === "/setup") return NextResponse.next();
    return NextResponse.redirect(new URL("/setup", request.url));
  }

  // Refresh the Supabase cookie session. Protected server pages/actions still
  // verify the user with auth.getUser() and enforce company membership/RLS.
  return updateSession(request);
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)"]
};
