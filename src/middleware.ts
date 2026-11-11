import { NextResponse, type NextRequest } from "next/server";
import { getSupabasePublicEnv } from "./lib/supabase/env";

const publicPaths = ["/login", "/setup", "/no-access", "/auth/callback"];

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  if (pathname.startsWith("/_next") || pathname === "/favicon.ico") return NextResponse.next();

  if (!getSupabasePublicEnv()) {
    if (pathname === "/setup") return NextResponse.next();
    return NextResponse.redirect(new URL("/setup", request.url));
  }

  if (publicPaths.some((path) => pathname === path || pathname.startsWith(path + "/"))) {
    return NextResponse.next();
  }

  // Cookie presence is only a routing hint, never proof of identity.
  // Every protected server page/action verifies the session with Supabase Auth
  // and checks company membership before it reads or writes business records.
  const hasSessionCookie = request.cookies.getAll().some(({ name }) =>
    /^sb-.+-auth-token(?:\.\d+)?$/.test(name)
  );

  if (!hasSessionCookie) {
    const loginUrl = new URL("/login", request.url);
    loginUrl.searchParams.set("next", pathname);
    return NextResponse.redirect(loginUrl);
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)"]
};
