"use client";

import { createBrowserClient } from "@supabase/ssr";
import { getSupabasePublicEnv } from "./env";

export function createSupabaseBrowserClient() {
  const env = getSupabasePublicEnv();
  if (!env) throw new Error("BOKAN ERP authentication is not configured for this environment.");
  return createBrowserClient(env.url, env.publishableKey);
}
