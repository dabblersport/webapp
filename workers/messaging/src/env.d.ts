// Minimal D1 type declarations so the skeleton needs no type package. Shape per Cloudflare's D1 client API.
interface D1Result<T = unknown> {
  results: T[];
  success: boolean;
  meta: { changes?: number; [k: string]: unknown };
}
interface D1PreparedStatement {
  bind(...values: unknown[]): D1PreparedStatement;
  all<T = unknown>(): Promise<D1Result<T>>;
  run<T = unknown>(): Promise<D1Result<T>>;
  first<T = unknown>(): Promise<T | null>;
}
interface D1Database {
  prepare(query: string): D1PreparedStatement;
  batch<T = unknown>(statements: D1PreparedStatement[]): Promise<D1Result<T>[]>;
  exec(query: string): Promise<unknown>;
}

// KAN-581: the slice of the R2 bucket binding the Worker uses (Cloudflare's R2 Workers API). Binding name MEDIA.
interface R2ObjectBody {
  body: ReadableStream;
}
interface R2Bucket {
  put(key: string, value: ArrayBuffer | Uint8Array | ReadableStream, options?: {
    httpMetadata?: { contentType?: string };
    customMetadata?: Record<string, string>;
  }): Promise<unknown>;
  get(key: string): Promise<R2ObjectBody | null>;
  delete(key: string): Promise<void>;
}
