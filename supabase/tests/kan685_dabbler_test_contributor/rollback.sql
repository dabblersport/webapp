-- KAN-685 rollback: NONE after commit. AUTHORED, NEVER RUN.
-- trgfn_unified_persona_guard raises persona_conversion_blocked on contributor -> player, and the ticket forbids a guard
-- change. The only rollback is aborting inside the migration's own transaction (any failed check or step does that).
-- A reversal after commit needs a guard decision and goes to the CEO.
DO $$ BEGIN
  RAISE EXCEPTION 'KAN-685 has no rollback after commit: the persona guard blocks contributor -> player. Nothing was changed.';
END $$;
