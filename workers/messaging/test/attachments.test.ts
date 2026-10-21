// KAN-581 private image attachments. LOCAL-EMULATOR TESTS: Miniflare in-memory D1 and R2 + mocked msg_authorize. No network,
// no Cloudflare account, no live resource.
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { afterEach, describe, expect, it, vi } from "vitest";
import worker from "../src/index";
import {
  MAX_IMAGES_PER_MESSAGE,
  MAX_IMAGE_BYTES,
  UPLOADS_PER_USER_PER_HOUR,
  sniffImage,
} from "../src/media_policy";
import { CONV_A, CONV_B, authRow, env, localD1, mockFetch } from "./helpers";

afterEach(() => vi.unstubAllGlobals());

const BASE = "https://worker.local";
const H = { Authorization: "Bearer any.token.here" };
const UP = (n: number) => `9b2f7c1e-1111-4000-8000-${String(n).padStart(12, "0")}`;
const SEND_KEY = (n: number) => `9b2f7c1e-2222-4000-8000-${String(n).padStart(12, "0")}`;

// Real minimal headers: a 1x1 PNG, a JPEG with a SOF0 of 3x2, a WebP VP8X of 5x4.
const PNG = Uint8Array.from(
  [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 0x1f, 0x15, 0xc4, 0x89],
);
const JPEG = Uint8Array.from([
  0xff, 0xd8, 0xff, 0xe0, 0, 4, 0, 0, 0xff, 0xc0, 0, 17, 8, 0, 2, 0, 3, 3, 1, 0x22, 0, 2, 0x11, 1, 3, 0x11, 1, 0xff, 0xd9,
]);
const WEBP = (() => {
  const b = new Uint8Array(32);
  b.set([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, 0x56, 0x50, 0x38, 0x58, 10, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 3, 0, 0], 0);
  return b;
})();
const HEIC = (() => {
  const b = new Uint8Array(40);
  b.set([0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63], 0);
  return b;
})();
const PDF = new TextEncoder().encode("%PDF-1.7\n1 0 obj << /Type /Catalog >> endobj\ntrailer\n%%EOF padding padding");
const EXE = (() => {
  const b = new Uint8Array(64);
  b.set([0x4d, 0x5a, 0x90, 0], 0);
  return b;
})();

async function setup(extra: Record<string, unknown> = {}) {
  const { mf, db } = await localD1();
  const bucket = (await mf.getR2Bucket("MEDIA")) as unknown as R2Bucket & { list(): Promise<{ objects: { key: string }[] }> };
  const state = { row: authRow({ user_id: "alice" }) as Record<string, unknown> };
  const m = mockFetch(() => new Response(JSON.stringify([state.row]), { status: 200 }));
  const e = { ...env(db), MEDIA: bucket, ...extra } as unknown as Parameters<typeof worker.fetch>[1];
  return { db, bucket, state, e, ...m };
}

const upload = (e: Parameters<typeof worker.fetch>[1], bytes: Uint8Array, key = UP(1), over: Record<string, string> = {}, conv = CONV_A) =>
  worker.fetch(
    new Request(`${BASE}/v1/conversations/${conv}/attachments`, {
      method: "POST",
      headers: { ...H, "Idempotency-Key": key, "Content-Type": "image/png", "Content-Length": String(bytes.length), ...over },
      body: bytes,
    }),
    e,
  );
const send = (e: Parameters<typeof worker.fetch>[1], key: string, payload: unknown, conv = CONV_A) =>
  worker.fetch(
    new Request(`${BASE}/v1/conversations/${conv}/messages`, {
      method: "POST",
      headers: { ...H, "Idempotency-Key": key, "content-type": "application/json" },
      body: JSON.stringify(payload),
    }),
    e,
  );
const read = (e: Parameters<typeof worker.fetch>[1], id: string, headers: Record<string, string> = H) =>
  worker.fetch(new Request(`${BASE}/v1/attachments/${id}`, { headers }), e);
const list = (e: Parameters<typeof worker.fetch>[1], conv = CONV_A) =>
  worker.fetch(new Request(`${BASE}/v1/conversations/${conv}/messages`, { headers: H }), e);

const objects = async (bucket: { list(): Promise<{ objects: { key: string }[] }> }) => (await bucket.list()).objects.map((o) => o.key);

describe("type sniffing reads the bytes only", () => {
  it("JPEG, PNG and WebP are recognised with their size", () => {
    expect(sniffImage(PNG)).toEqual({ mime: "image/png", width: 1, height: 1 });
    expect(sniffImage(JPEG)).toEqual({ mime: "image/jpeg", width: 3, height: 2 });
    expect(sniffImage(WEBP)).toEqual({ mime: "image/webp", width: 5, height: 4 });
  });
  it("HEIC, PDF and executable bytes are not images", () => {
    expect(sniffImage(HEIC)).toBeNull();
    expect(sniffImage(PDF)).toBeNull();
    expect(sniffImage(EXE)).toBeNull();
    expect(sniffImage(new Uint8Array(0))).toBeNull();
  });
});

describe("upload (AC1, AC2, AC6)", () => {
  it("stores a valid image privately in R2 and a record in D1, and returns an id, never a URL", async () => {
    const t = await setup();
    const res = await upload(t.e, PNG);
    expect(res.status).toBe(201);
    const { attachment } = (await res.json()) as { attachment: Record<string, unknown> };
    expect(attachment).toMatchObject({ mime_type: "image/png", byte_size: PNG.length, width: 1, height: 1 });
    expect(Object.keys(attachment).sort()).toEqual(["byte_size", "height", "id", "mime_type", "width"]);
    expect(await objects(t.bucket)).toEqual([`m/${CONV_A}/${attachment.id}`]);
    const row = await t.db.prepare("SELECT uploader_id, message_id FROM message_attachments").first<{ uploader_id: string; message_id: string | null }>();
    expect(row).toEqual({ uploader_id: "alice", message_id: null });
  });

  it("a retried upload (same Idempotency-Key) returns the same attachment and stores one object", async () => {
    const t = await setup();
    const a = (await (await upload(t.e, PNG)).json()) as { attachment: { id: string } };
    const again = await upload(t.e, PNG);
    expect(again.status).toBe(200);
    expect(((await again.json()) as { attachment: { id: string } }).attachment.id).toBe(a.attachment.id);
    expect((await objects(t.bucket)).length).toBe(1);
  });

  it("refuses an oversized body from its Content-Length before authorising or reading it (413)", async () => {
    const t = await setup();
    const res = await upload(t.e, PNG, UP(1), { "Content-Length": String(MAX_IMAGE_BYTES + 1) });
    expect(res.status).toBe(413);
    expect(((await res.json()) as { error: { reason: string } }).error.reason).toBe("payload_too_large");
    expect(t.calls.length).toBe(0);
    expect(await objects(t.bucket)).toEqual([]);
  });

  it("refuses a real body over the limit even when the header lies (413)", async () => {
    const t = await setup();
    const big = new Uint8Array(MAX_IMAGE_BYTES + 1);
    big.set(PNG, 0);
    const res = await upload(t.e, big, UP(2), { "Content-Length": "100" });
    expect([400, 413]).toContain(res.status);
    expect(await objects(t.bucket)).toEqual([]);
  });

  it("requires a Content-Length (400)", async () => {
    const t = await setup();
    const res = await worker.fetch(
      new Request(`${BASE}/v1/conversations/${CONV_A}/attachments`, {
        method: "POST",
        headers: { ...H, "Idempotency-Key": UP(3), "Content-Type": "image/png", "Content-Length": "abc" },
        body: PNG,
      }),
      t.e,
    );
    expect(res.status).toBe(400);
  });

  for (const [name, bytes, declared] of [
    ["a PDF declared as an image", PDF, "image/png"],
    ["an executable declared as an image", EXE, "image/jpeg"],
    ["HEIC bytes", HEIC, "image/heic"],
    ["PNG bytes declared as JPEG", PNG, "image/jpeg"],
    ["PNG bytes declared as a PDF", PNG, "application/pdf"],
    ["PNG bytes with no declared type", PNG, ""],
  ] as const) {
    it(`rejects ${name} (415) and stores nothing`, async () => {
      const t = await setup();
      const res = await upload(t.e, bytes, UP(4), { "Content-Type": declared });
      expect(res.status).toBe(415);
      expect(((await res.json()) as { error: { reason: string } }).error.reason).toBe("unsupported_media_type");
      expect(await objects(t.bucket)).toEqual([]);
      expect((await t.db.prepare("SELECT COUNT(*) AS n FROM message_attachments").first<{ n: number }>())?.n).toBe(0);
    });
  }

  it("a non-member is refused with the typed reason and nothing is written", async () => {
    const t = await setup();
    t.state.row = authRow({ allowed_action: null, reason: "not_member", user_id: null });
    const res = await upload(t.e, PNG);
    expect(res.status).toBe(403);
    expect(((await res.json()) as { error: { reason: string } }).error.reason).toBe("not_a_member");
    expect(await objects(t.bucket)).toEqual([]);
  });

  it("a read-only member (game ended) cannot upload (409)", async () => {
    const t = await setup();
    t.state.row = authRow({ allowed_action: "read", reason: "game_ended" });
    const res = await upload(t.e, PNG);
    expect(res.status).toBe(409);
    expect(await objects(t.bucket)).toEqual([]);
  });

  it("no token is 401", async () => {
    const t = await setup();
    const res = await upload(t.e, PNG, UP(5), { Authorization: "" });
    expect(res.status).toBe(401);
    expect(await objects(t.bucket)).toEqual([]);
  });

  it("without the R2 binding every attachment route answers 503 and writes nothing", async () => {
    const t = await setup({ MEDIA: undefined });
    expect((await upload(t.e, PNG)).status).toBe(503);
    expect((await t.db.prepare("SELECT COUNT(*) AS n FROM message_attachments").first<{ n: number }>())?.n).toBe(0);
  });

  it("the MESSAGING_UPLOADS kill switch refuses new uploads (503) and leaves reads working", async () => {
    const t = await setup();
    const [id] = await uploaded(t, 1);
    await send(t.e, SEND_KEY(1), { attachment_ids: [id] });
    const off = { ...(t.e as object), MESSAGING_UPLOADS: "off" } as unknown as Parameters<typeof worker.fetch>[1];
    expect((await upload(off, PNG, UP(77))).status).toBe(503);
    expect((await read(off, id)).status).toBe(200);
    expect((await objects(t.bucket)).length).toBe(1);
  });

  it(`the ${UPLOADS_PER_USER_PER_HOUR + 1}th upload in an hour is 429 with Retry-After`, async () => {
    const t = await setup();
    for (let i = 0; i < UPLOADS_PER_USER_PER_HOUR; i++) expect((await upload(t.e, PNG, UP(100 + i))).status).toBe(201);
    const res = await upload(t.e, PNG, UP(999));
    expect(res.status).toBe(429);
    expect(res.headers.get("Retry-After")).not.toBeNull();
    expect((await objects(t.bucket)).length).toBe(UPLOADS_PER_USER_PER_HOUR);
  });
});

async function uploaded(t: Awaited<ReturnType<typeof setup>>, n: number, bytes = PNG) {
  const ids: string[] = [];
  for (let i = 0; i < n; i++) ids.push(((await (await upload(t.e, bytes, UP(10 + i))).json()) as { attachment: { id: string } }).attachment.id);
  return ids;
}

describe("binding to a message (AC2 attachment binding)", () => {
  it("an image-only message binds the uploader's attachments in order and the list shows them", async () => {
    const t = await setup();
    const ids = await uploaded(t, 2);
    const res = await send(t.e, SEND_KEY(1), { attachment_ids: ids });
    expect(res.status).toBe(201);
    const msg = (await res.json()) as { body: string; attachments: { id: string }[] };
    expect(msg.body).toBe("");
    expect(msg.attachments.map((a) => a.id)).toEqual(ids);
    const page = (await (await list(t.e)).json()) as { messages: { attachments?: { id: string }[] }[] };
    expect(page.messages[0].attachments?.map((a) => a.id)).toEqual(ids);
  });

  it("a caption plus an image works; a plain text message has no attachments key", async () => {
    const t = await setup();
    const [id] = await uploaded(t, 1);
    const withCaption = (await (await send(t.e, SEND_KEY(1), { body: "look", attachment_ids: [id] })).json()) as Record<string, unknown>;
    expect(withCaption.body).toBe("look");
    const plain = (await (await send(t.e, SEND_KEY(2), { body: "hi" })).json()) as Record<string, unknown>;
    expect("attachments" in plain).toBe(false);
  });

  it("a repeat of the same send (same Idempotency-Key) is 200 with the same attachments and binds nothing twice", async () => {
    const t = await setup();
    const ids = await uploaded(t, 1);
    const first = await send(t.e, SEND_KEY(1), { attachment_ids: ids });
    const again = await send(t.e, SEND_KEY(1), { attachment_ids: ids });
    expect(first.status).toBe(201);
    expect(again.status).toBe(200);
    expect(((await again.json()) as { attachments: unknown[] }).attachments.length).toBe(1);
    expect((await t.db.prepare("SELECT COUNT(*) AS n FROM messages").first<{ n: number }>())?.n).toBe(1);
  });

  it("text-only still needs text", async () => {
    const t = await setup();
    expect((await send(t.e, SEND_KEY(1), {})).status).toBe(400);
    expect((await send(t.e, SEND_KEY(2), { body: "" })).status).toBe(400);
  });

  it("refuses someone else's attachment, another conversation's, an already-bound one, a duplicate, an unknown id and too many", async () => {
    const t = await setup();
    const [mine] = await uploaded(t, 1);
    // someone else's
    t.state.row = authRow({ user_id: "bob" });
    expect((await send(t.e, SEND_KEY(1), { attachment_ids: [mine] })).status).toBe(400);
    t.state.row = authRow({ user_id: "alice" });
    // another conversation
    const other = ((await (await upload(t.e, PNG, UP(50), {}, CONV_B)).json()) as { attachment: { id: string } }).attachment.id;
    expect((await send(t.e, SEND_KEY(2), { attachment_ids: [other] })).status).toBe(400);
    // duplicate id in one message
    expect((await send(t.e, SEND_KEY(3), { attachment_ids: [mine, mine] })).status).toBe(400);
    // unknown id
    expect((await send(t.e, SEND_KEY(4), { attachment_ids: ["00000000-0000-4000-8000-000000000000"] })).status).toBe(400);
    // too many
    const many = await uploaded(t, MAX_IMAGES_PER_MESSAGE + 1);
    expect((await send(t.e, SEND_KEY(5), { attachment_ids: many })).status).toBe(400);
    // bound once, then not reusable by another message
    expect((await send(t.e, SEND_KEY(6), { attachment_ids: [mine] })).status).toBe(201);
    expect((await send(t.e, SEND_KEY(7), { attachment_ids: [mine] })).status).toBe(400);
    // a failed send stored no message
    expect((await t.db.prepare("SELECT COUNT(*) AS n FROM messages").first<{ n: number }>())?.n).toBe(1);
  });
});

describe("authorised read (AC2, TC6)", () => {
  async function sent(t: Awaited<ReturnType<typeof setup>>) {
    const ids = await uploaded(t, 1);
    await send(t.e, SEND_KEY(1), { attachment_ids: ids });
    return ids[0];
  }

  it("a member reads the bytes with private headers", async () => {
    const t = await setup();
    const id = await sent(t);
    t.state.row = authRow({ user_id: "bob" });
    const res = await read(t.e, id);
    expect(res.status).toBe(200);
    expect(res.headers.get("content-type")).toBe("image/png");
    expect(res.headers.get("cache-control")).toContain("private");
    expect(res.headers.get("x-content-type-options")).toBe("nosniff");
    expect(new Uint8Array(await res.arrayBuffer())).toEqual(PNG);
  });

  it("signed out is 401", async () => {
    const t = await setup();
    const id = await sent(t);
    expect((await read(t.e, id, {})).status).toBe(401);
  });

  it("a rejected token is 401", async () => {
    const t = await setup();
    const id = await sent(t);
    const rejected = mockFetch(() => new Response("{}", { status: 401 }));
    void rejected;
    expect((await read(t.e, id)).status).toBe(401);
  });

  it("a non-member (or removed user) gets 404, the same as a missing id", async () => {
    const t = await setup();
    const id = await sent(t);
    t.state.row = authRow({ allowed_action: null, reason: "not_member", user_id: null });
    const denied = await read(t.e, id);
    expect(denied.status).toBe(404);
    t.state.row = authRow({ allowed_action: null, reason: "removed", user_id: null });
    expect((await read(t.e, id)).status).toBe(404);
    t.state.row = authRow({ user_id: "bob" });
    expect((await read(t.e, "00000000-0000-4000-8000-000000000000")).status).toBe(404);
  });

  it("a member who left cannot read an image sent after they left", async () => {
    const t = await setup();
    const id = await sent(t);
    t.state.row = authRow({ user_id: "bob", allowed_action: "read", reason: "left", left_at_seq: 0 });
    expect((await read(t.e, id)).status).toBe(404);
    t.state.row = authRow({ user_id: "bob", allowed_action: "read", reason: "left", left_at_seq: 1 });
    expect((await read(t.e, id)).status).toBe(200);
  });

  it("an image from a sender the viewer blocked is 404", async () => {
    const t = await setup();
    const id = await sent(t);
    t.state.row = authRow({ user_id: "bob", hidden_sender_ids: ["alice"] });
    expect((await read(t.e, id)).status).toBe(404);
  });

  it("an unsent attachment is readable only by its uploader", async () => {
    const t = await setup();
    const [id] = await uploaded(t, 1);
    expect((await read(t.e, id)).status).toBe(200);
    t.state.row = authRow({ user_id: "bob" });
    expect((await read(t.e, id)).status).toBe(404);
  });
});

describe("provider boundary (AC6)", () => {
  it("the Worker source never touches Supabase Storage or stores message bodies in Supabase", () => {
    const dir = fileURLToPath(new URL("../src/", import.meta.url));
    for (const f of readdirSync(dir).filter((n) => n.endsWith(".ts"))) {
      const text = readFileSync(dir + f, "utf8");
      expect(text, f).not.toMatch(/storage\/v1|\.storage\.from|createSignedUrl|getPublicUrl/);
    }
  });
});
