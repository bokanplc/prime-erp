"use client";

import { createBrowserClient } from "@supabase/ssr";
import { getPublicSupabaseEnv } from "./env";

export function createSupabaseBrowserClient() {
  const env = getPublicSupabaseEnv();
  if (!env) throw new Error("Supabase authentication is not configured for this deployment.");
  return createBrowserClient(env.NEXT_PUBLIC_SUPABASE_URL, env.NEXT_PUBLIC_SUPABASE_ANON_KEY);
}
