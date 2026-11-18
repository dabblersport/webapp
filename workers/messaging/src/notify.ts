// KAN-543 (Realtime R3): after a NEW user message is stored, ask Supabase to wake the members' private Realtime
// topics. public.msg_notify (KAN-541) decides who is woken from the caller's own identity; the Worker holds no
// elevated key: the call forwards the caller's Authorization UNCHANGED, with the anon key as `apikey` (the same way
// auth.ts calls msg_authorize).
//
// KAN-984 (W1-B6): the message text, cut to SNIPPET_MAX_CHARS, goes along as `p_snippet` so the push can show the
// sender and a snippet (F-2). Supabase decides per recipient whether it is shown (message_preview) and never stores
// it: it travels in the push only. An empty caption (images only) sends no snippet, which selects the three-argument
// msg_notify and a sender-only push.
//
// KAN-984c (option A, CEO 2026-11-17): the snippet is accepted by Supabase only with a proof that THIS Worker sent it.
// The header `x-msg-snippet-mac` carries HMAC-SHA256(key, "<conversation id>:<seq>:<snippet>") as lowercase hex.
// The key is the Worker secret MSG_SNIPPET_HMAC_KEY (binding name only, no value in the repo) and the same value is the
// Supabase Vault secret `msg_snippet_hmac_key`. A missing or wrong MAC makes Supabase drop the snippet (sender-only
// push); it never fails the call. Without the binding the Worker sends no snippet at all. The key itself never leaves
// the Worker: only the MAC travels, and a MAC is bound to one conversation, one seq and one exact text.
//
// Fire-and-forget: callers schedule this through ctx.waitUntil and never await it before responding. Every failure
// is swallowed and nothing is logged: the KAN-513 guard (t18) forbids any console call in src, and the token, the
// headers, the body and the message text must never reach a log anyway. The outcome is only the returned status
// code (null when the call could not be made), which the waitUntil promise carries and tests can read.

import { Env, accessMode } from "./auth";
import { snippetMac } from "./snippet_mac";

export { snippetMac };

/** The part of the Workers ExecutionContext this code uses. */
export interface WaitUntilContext {
  waitUntil(promise: Promise<unknown>): void;
}

/** KAN-984c: the snippet key binding. Declared here so the shared Env stays untouched; absent = no snippet sent. */
export type NotifyEnv = Env & { MSG_SNIPPET_HMAC_KEY?: string };

const NOTIFY_TIMEOUT_MS = 5000;

/** KAN-984: longest snippet sent to Supabase; msg_notify cuts it again to 140 characters for the push. */
export const SNIPPET_MAX_CHARS = 200;

/** KAN-984c: the request header that carries the snippet MAC (PostgREST exposes it lowercased in request.headers). */
export const SNIPPET_MAC_HEADER = "x-msg-snippet-mac";

/**
 * The snippet to send: the trimmed text, at most SNIPPET_MAX_CHARS characters; null when there is no text.
 * Control characters become spaces and lone surrogates become U+FFFD, so the exact string the MAC covers is the exact
 * string Postgres receives (a NUL or a lone surrogate cannot travel through JSON into a Postgres text value).
 */
export function snippetOf(body: string | null | undefined): string | null {
  const text = (body ?? "")
    .replace(/[\u0000-\u001f\u007f]/g, " ")
    .replace(/[\ud800-\udbff](?![\udc00-\udfff])|(?<![\ud800-\udbff])[\udc00-\udfff]/g, "�")
    .trim();
  if (text.length === 0) return null;
  return Array.from(text).slice(0, SNIPPET_MAX_CHARS).join("");
}

export async function notifyMembers(
  env: NotifyEnv,
  authorization: string,
  conversationId: string,
  seq: number,
  body?: string | null,
): Promise<number | null> {
  if (!env.SUPABASE_URL || !env.SUPABASE_ANON_KEY) return null;
  try {
    const key = env.MSG_SNIPPET_HMAC_KEY;
    const snippet = key ? snippetOf(body) : null; // no key: no snippet leaves the Worker
    const headers: Record<string, string> = {
      apikey: env.SUPABASE_ANON_KEY,
      Authorization: authorization,
      "Content-Type": "application/json",
      Accept: "application/json",
    };
    if (snippet !== null && key) headers[SNIPPET_MAC_HEADER] = await snippetMac(key, conversationId, seq, snippet);
    const res = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/msg_notify`, {
      method: "POST",
      headers,
      body: JSON.stringify({
        p_conversation_id: conversationId,
        p_seq: seq,
        p_access_mode: accessMode(env),
        ...(snippet !== null ? { p_snippet: snippet } : {}),
      }),
      signal: AbortSignal.timeout(NOTIFY_TIMEOUT_MS),
    });
    return res.status;
  } catch {
    return null; // network error, timeout or a crypto failure: swallowed
  }
}

/** Schedules the wake-up after the response. A missing context (a plain unit call) schedules nothing. */
export function scheduleNotify(
  ctx: WaitUntilContext | undefined,
  env: NotifyEnv,
  authorization: string | null,
  conversationId: string,
  seq: number,
  body?: string | null,
): void {
  if (!ctx || authorization === null) return;
  ctx.waitUntil(notifyMembers(env, authorization, conversationId, seq, body));
}
