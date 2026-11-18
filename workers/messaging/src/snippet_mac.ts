// KAN-984c (option A, CEO 2026-11-17): the MAC that lets Supabase accept a push snippet from this Worker.
//
// HMAC-SHA256(key, "<conversation id lowercased>:<seq>:<snippet>") as lowercase hex. public.msg_snippet_verified
// recomputes the same value with pgcrypto from the Vault secret `msg_snippet_hmac_key`; the Worker holds the same value
// as the secret binding MSG_SNIPPET_HMAC_KEY (binding name only, no value in the repo).
//
// This module is the only place that signs, and it is kept apart from notify.ts on purpose: it receives the key and
// the three signed fields, never a request, a header or a bearer token (the static guard allows crypto.subtle here and
// in system_line.ts only).

export async function snippetMac(key: string, conversationId: string, seq: number, snippet: string): Promise<string> {
  const enc = new TextEncoder();
  const k = await crypto.subtle.importKey("raw", enc.encode(key), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = new Uint8Array(
    await crypto.subtle.sign("HMAC", k, enc.encode(`${conversationId.toLowerCase()}:${seq}:${snippet}`)),
  );
  return Array.from(sig, (b) => b.toString(16).padStart(2, "0")).join("");
}
