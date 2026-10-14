// Typed error responses per the T7 contract (docs/messaging/openapi.yaml, components.schemas.Reason/ErrorBody).
// A 401 (token missing or rejected) and a 5XX carry NO reason (contract: "the client maps them to unknown").

export const REASON_STATUS = {
  not_in_pilot: 403,
  not_a_member: 403,
  removed: 403,
  left_read_only: 403,
  game_ended: 409,
  game_cancelled: 409,
  blocked: 403,
  suspended: 403,
  rate_limited: 429,
  not_found: 404,
  invalid_request: 400,
} as const;

export type Reason = keyof typeof REASON_STATUS;

export function isReason(v: unknown): v is Reason {
  return typeof v === "string" && Object.prototype.hasOwnProperty.call(REASON_STATUS, v);
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

/** A typed-reason failure: status taken from the contract's per-reason table. */
export function reasonError(reason: Reason, message?: string): Response {
  const error: Record<string, unknown> = { reason };
  if (message) error.message = message;
  return json(REASON_STATUS[reason], { error });
}

/** 401: token missing or rejected. No reason, by contract. */
export function unauthenticated(message = "unauthenticated"): Response {
  return json(401, { error: { message } });
}

/** 403 for a denial whose reason this build does not know: no reason sent (client maps to unknown). */
export function deniedWithoutReason(message = "denied"): Response {
  return json(403, { error: { message } });
}

/** 5XX: upstream authorisation failure or misconfiguration. No reason, by contract. */
export function upstreamError(status: 500 | 502 | 503, message: string): Response {
  return json(status, { error: { message } });
}

export function ok(body: unknown): Response {
  return json(200, body);
}
