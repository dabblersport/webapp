-- Fix hashtag trigger/function failures caused by missing hashtags.updated_at.
-- Error addressed: 42703 column "updated_at" of relation "hashtags" does not exist

alter table if exists public.hashtags
add column if not exists updated_at timestamp with time zone default now();

-- Backfill any nulls defensively.
update public.hashtags
set updated_at = now()
where updated_at is null;

-- Keep updated_at fresh on writes.
create or replace function public.set_current_timestamp_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_hashtags_updated_at on public.hashtags;

create trigger trg_hashtags_updated_at
before update on public.hashtags
for each row
execute function public.set_current_timestamp_updated_at();
