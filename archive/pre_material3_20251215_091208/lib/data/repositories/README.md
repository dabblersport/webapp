Repositories coordinate data access, translating Supabase responses into domain models.
Always return a `Result<T>` so failures are surfaced consistently to the UI layer.
Keep queries lean and defer complex authorization to server-side row level security.
Prefer small focused classes with injectable dependencies via Riverpod providers.
