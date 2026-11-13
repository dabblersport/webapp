// KAN-543 (Realtime R3): after a NEW user message is stored, ask Supabase to wake the members' private Realtime
// topics. public.msg_notify (KAN-541) decides who is woken from the caller's own identity; the Worker holds no
// elevated key and sends only ids: the call forwards the caller's Authorization UNCHANGED, with the anon key as
// `apikey` (the same way auth.ts calls msg_authorize).
//
// Fire-and-forget: callers schedule this through ctx.waitUntil and never await it before responding. Every failure
// is swallowed and nothing is logged: the KAN-513 guard (t18) forbids any console call in src, and the token, the
// headers, the body and the message text must never reach a log anyway. The outcome is only the returned status
// code (null when the call could not be made), which the waitUntil promise carries and tests can read.

import { Env, accessMode } from "./auth";

/** The part of the Workers ExecutionContext this code uses. */
export interface WaitUntilContext {
  waitUntil(promise: Promise<unknown>): void;
}

const NOTIFY_TIMEOUT_MS = 5000;

export async function notifyMembers(
  env: Env,
  authorization: string,
  conversationId: string,
  seq: number,
): Promise<number | null> {
  if (!env.SUPABASE_URL || !env.SUPABASE_ANON_KEY) return null;
  try {
    const res = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/msg_notify`, {
      method: "POST",
      headers: {
        apikey: env.SUPABASE_ANON_KEY,
        Authorization: authorization,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({
        p_conversation_id: conversationId,
        p_seq: seq,
        p_access_mode: accessMode(env),
      }),
      signal: AbortSignal.timeout(NOTIFY_TIMEOUT_MS),
    });
    return res.status;
  } catch {
    return null; // network error or timeout: swallowed
  }
}

/** Schedules the wake-up after the response. A missing context (a plain unit call) schedules nothing. */
export function scheduleNotify(
  ctx: WaitUntilContext | undefined,
  env: Env,
  authorization: string | null,
  conversationId: string,
  seq: number,
): void {
  if (!ctx || authorization === null) return;
  ctx.waitUntil(notifyMembers(env, authorization, conversationId, seq));
}
