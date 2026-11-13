// KAN-581: the ONE place the image rules live. Every number here is a PROVISIONAL recommendation: the CEO has not
// approved a format list, a size, a count or a compression rule (ticket checks 7 and 8). Changing a decision changes one
// row of this file, and test/attachments.test.ts reads the constants rather than repeating them.
// The Flutter app mirrors them in lib/features/messaging/domain/image_policy.dart (a test there pins the same numbers).

/** Provisional: 10 MiB per image after the app's own downscale. */
export const MAX_IMAGE_BYTES = 10 * 1024 * 1024;
/** Provisional: images in one message. */
export const MAX_IMAGES_PER_MESSAGE = 4;
/** Provisional: uploads one user may start in an hour (a refused one stores nothing). */
export const UPLOADS_PER_USER_PER_HOUR = 40;
/** An upload below this is not an image (the smallest valid header). */
export const MIN_IMAGE_BYTES = 24;

export const ALLOWED_IMAGE_TYPES = ["image/jpeg", "image/png", "image/webp"] as const;
export type ImageType = (typeof ALLOWED_IMAGE_TYPES)[number];

export interface SniffedImage {
  mime: ImageType;
  width: number | null;
  height: number | null;
}

const u16be = (b: Uint8Array, i: number) => (b[i] << 8) | b[i + 1];
const u32be = (b: Uint8Array, i: number) => ((b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3]) >>> 0;
const ascii = (b: Uint8Array, i: number, s: string) => {
  for (let k = 0; k < s.length; k++) if (b[i + k] !== s.charCodeAt(k)) return false;
  return true;
};
const positive = (n: number) => (Number.isInteger(n) && n >= 1 ? n : null);

function jpegSize(b: Uint8Array): { width: number | null; height: number | null } {
  let i = 2;
  while (i + 9 < b.length) {
    if (b[i] !== 0xff) {
      i++;
      continue;
    }
    const marker = b[i + 1];
    if (marker === 0xff) {
      i++;
      continue;
    }
    if (marker === 0xd8 || marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) {
      i += 2;
      continue;
    }
    const len = u16be(b, i + 2);
    const sof = marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc;
    if (sof) return { height: positive(u16be(b, i + 5)), width: positive(u16be(b, i + 7)) };
    if (len < 2) break;
    i += 2 + len;
  }
  return { width: null, height: null };
}

function webpSize(b: Uint8Array): { width: number | null; height: number | null } {
  if (b.length >= 30 && ascii(b, 12, "VP8X")) {
    return {
      width: positive(1 + (b[24] | (b[25] << 8) | (b[26] << 16))),
      height: positive(1 + (b[27] | (b[28] << 8) | (b[29] << 16))),
    };
  }
  if (b.length >= 30 && ascii(b, 12, "VP8L") && b[20] === 0x2f) {
    return {
      width: positive(1 + (((b[22] & 0x3f) << 8) | b[21])),
      height: positive(1 + (((b[24] & 0x0f) << 10) | (b[23] << 2) | ((b[22] & 0xc0) >> 6))),
    };
  }
  if (b.length >= 30 && ascii(b, 12, "VP8 ") && b[23] === 0x9d && b[24] === 0x01 && b[25] === 0x2a) {
    return {
      width: positive((b[26] | (b[27] << 8)) & 0x3fff),
      height: positive((b[28] | (b[29] << 8)) & 0x3fff),
    };
  }
  return { width: null, height: null };
}

/**
 * The real type of [b], decided from its bytes only (never from a filename or a declared content type). Returns null for
 * anything that is not JPEG, PNG or WebP: HEIC/HEIF, GIF, SVG, PDF, executables and text all land here.
 */
export function sniffImage(b: Uint8Array): SniffedImage | null {
  if (b.length < MIN_IMAGE_BYTES) return null;
  if (b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return { mime: "image/jpeg", ...jpegSize(b) };
  if (b[0] === 0x89 && ascii(b, 1, "PNG") && b[4] === 0x0d && b[5] === 0x0a && b[6] === 0x1a && b[7] === 0x0a) {
    const ok = ascii(b, 12, "IHDR");
    return { mime: "image/png", width: ok ? positive(u32be(b, 16)) : null, height: ok ? positive(u32be(b, 20)) : null };
  }
  if (ascii(b, 0, "RIFF") && ascii(b, 8, "WEBP")) return { mime: "image/webp", ...webpSize(b) };
  return null;
}

/** A declared content type is checked against the sniffed one; parameters (";charset=...") are ignored. */
export function declaredMatches(declared: string | null, sniffed: ImageType): boolean {
  const base = (declared ?? "").split(";")[0].trim().toLowerCase();
  return base === sniffed;
}
