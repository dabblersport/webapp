// KAN-545: pure guards and decoders. No network, no I/O. Everything here is unit tested.

export const PROJECT_REF = "wtncuzcskpigqpmnxwws";
export const FIXTURE_GAME_ID = "16223736-0ebb-4088-b823-91f3f9ef5643";
/** The platform adds `id` to every wake, so the allowed key set is a subset of these four. */
export const ALLOWED_WAKE_KEYS = Object.freeze(["type", "conversation_id", "seq", "id"]);

export class GuardError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "GuardError";
    this.code = code;
  }
}

/** True when every key is one of type, conversation_id, seq, id. */
export function keysAllowed(keys) {
  return Array.isArray(keys) && keys.every((k) => ALLOWED_WAKE_KEYS.includes(k));
}

/**
 * exp - iat of a JWT, in whole seconds. Reads only those two numeric claims and returns a number;
 * the token, its other claims and its signature are never returned, stored or printed.
 */
export function decodeExpMinusIat(jwt) {
  if (typeof jwt !== "string") throw new TypeError("token must be a string");
  const parts = jwt.split(".");
  if (parts.length !== 3) throw new TypeError("not a JWT");
  let claims;
  try {
    claims = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8"));
  } catch {
    throw new TypeError("unreadable JWT payload");
  }
  if (!Number.isFinite(claims.exp) || !Number.isFinite(claims.iat)) throw new TypeError("exp or iat missing");
  return claims.exp - claims.iat;
}

/** exp of a JWT as epoch seconds (a number only). */
export function decodeExp(jwt) {
  const parts = String(jwt).split(".");
  if (parts.length !== 3) throw new TypeError("not a JWT");
  const claims = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8"));
  if (!Number.isFinite(claims.exp)) throw new TypeError("exp missing");
  return claims.exp;
}

/** Refuses anything but the one staging project. Accepts https://<ref>.supabase.co only. */
export function assertProjectUrl(url) {
  let host;
  try {
    const u = new URL(String(url));
    if (u.protocol !== "https:") throw new Error("not https");
    host = u.hostname.toLowerCase();
  } catch {
    throw new GuardError("wrong-project", "SUPABASE_URL is missing or not an https URL");
  }
  if (host !== `${PROJECT_REF}.supabase.co`) {
    throw new GuardError("wrong-project", `SUPABASE_URL is not the project ${PROJECT_REF}`);
  }
}

/** Every profile of the account must be a test profile (username or display name contains "test"). */
export function assertTestProfiles(label, profiles) {
  if (!Array.isArray(profiles) || profiles.length === 0) {
    throw new GuardError("no-profile", `${label}: no profile found`);
  }
  for (const p of profiles) {
    const hay = `${p?.username ?? ""} ${p?.display_name ?? ""}`.toLowerCase();
    if (!hay.includes("test")) {
      throw new GuardError("not-a-test-profile", `${label}: a profile is not a test profile`);
    }
  }
}

/** The account may be active on the fixture game only. Left or kicked rows are history and ignored. */
export function assertOnlyFixtureGame(label, rosterRows, fixtureGameId = FIXTURE_GAME_ID) {
  const rows = Array.isArray(rosterRows) ? rosterRows : [];
  const foreign = rows.filter((r) => r.status === "active" && r.game_id !== fixtureGameId);
  if (foreign.length > 0) {
    throw new GuardError("foreign-game", `${label}: active on ${foreign.length} game(s) other than the fixture game`);
  }
}

/** The runner needs both accounts active on the fixture game to start. */
export function assertOnFixtureGame(label, rosterRows, fixtureGameId = FIXTURE_GAME_ID) {
  const on = (rosterRows ?? []).some((r) => r.status === "active" && r.game_id === fixtureGameId);
  if (!on) throw new GuardError("not-on-fixture", `${label}: not an active member of the fixture game`);
}

/** All guards in the order the runner applies them. `facts` is {A: {profiles, roster}, B: {...}}. */
export function runGuards({ supabaseUrl, facts }) {
  assertProjectUrl(supabaseUrl);
  for (const label of ["A", "B"]) {
    assertTestProfiles(label, facts[label].profiles);
    assertOnlyFixtureGame(label, facts[label].roster);
    assertOnFixtureGame(label, facts[label].roster);
  }
}
