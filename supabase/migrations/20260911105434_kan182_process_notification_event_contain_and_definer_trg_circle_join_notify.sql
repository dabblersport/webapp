-- KAN-182 -- public.process_notification_event: root fix.
-- Measured live against wtncuzcskpigqpmnxwws immediately before applying.
--
-- THE DEFECT AS IT STOOD TODAY. anon EXECUTE was revoked on 2026-09-10
-- (docs/SCHEMA.md 2g.1), but `authenticated` STILL HELD IT:
--   proacl = {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
-- This function is SECURITY DEFINER and takes p_to_user_id (arbitrary target),
-- p_title / p_body (arbitrary text) and p_entity_id (which becomes the
-- action_route deep link). So ANY signed-up user could deliver arbitrary text
-- and an arbitrary deep link into ANY other user's trusted in-app notification
-- feed. Narrowing to `authenticated` reduced the attacker pool to people with
-- an account; it did not remove the primitive. That is what this closes.
--
-- APPROACH: GATE REACHABILITY, DO NOT DELETE THE PARAMETERS.
-- The ticket's AC3 asks for server-controlled templated title/body instead of
-- caller-supplied free text. Implemented literally that BREAKS PRODUCTION, and
-- the ticket does not say so: the body ALREADY templates from p_kind_key (a 20
-- branch CASE), and p_title/p_body are OVERRIDES that legitimate internal
-- callers use -- e.g. rpc_decide_join_request passes
-- 'You''re in! Your request to join was accepted'. Deleting the parameters
-- would break those call sites. So AC3's INTENT (no untrusted caller may write
-- notification text or choose a deep link) is met by removing every untrusted
-- caller, leaving the parameters intact for the trusted internal paths.
-- AC3's literal mechanism is deliberately NOT implemented. Stated, not silent.
--
-- AC3 also asks that any legitimate free-text path be separately authorized and
-- distinct. IT ALREADY IS, and no new path was built: admin broadcasts go
-- through rpc_broadcast_inapp_notification, called by the broadcast-notification
-- edge function with the service_role key behind an is_admin() check.
--
-- WHY STATEMENT 1 IS REQUIRED AND IS NOT INCIDENTAL.
-- 19 in-database caller functions reference this function (22 textual call sites;
-- several callers call it more than once -- a "21 callers" figure quoted upstream
-- is a call-site count, not a function count). 18 of the 19 are SECURITY DEFINER
-- owned by postgres, so they keep working after the revoke: they execute as
-- postgres, which retains EXECUTE. trg_circle_join_notify IS THE SINGLE EXCEPTION
-- -- it is SECURITY INVOKER, and it is attached to circle_members. Revoking
-- `authenticated` WITHOUT this ALTER would make the inner PERFORM raise 42501
-- for an authenticated user, and JOINING A CIRCLE WOULD FAIL OUTRIGHT. All 14 of
-- its sibling trg_*_notify functions are already SECURITY DEFINER; this one
-- being INVOKER is the anomaly, not the rule.
--
-- DISCLOSED BEHAVIOUR CHANGE: as SECURITY DEFINER, trg_circle_join_notify's
-- reads of circles/profiles are no longer RLS-constrained, so it now resolves a
-- circle owner it may previously have missed (returning early and sending no
-- notification). That is a fix, not a regression, and it matches the 14
-- siblings. No disclosure vector: the rows only select a notification
-- recipient and are never returned to the caller. Its search_path is already
-- pinned to 'public','pg_temp', so making it DEFINER introduces no
-- search_path vulnerability.
--
-- STATEMENT FORM: ALTER / REVOKE / COMMENT only. No CREATE OR REPLACE and no
-- DROP+CREATE, so both ACLs and both bodies are preserved byte-for-byte.
-- pg_default_acl still grants anon EXECUTE on new functions in public
-- (KAN-189/KAN-194, unfixed), so a recreate would silently re-open this.
-- No body is restated, so T-058 does not arise.
--
-- PUBLIC is named explicitly: a bare =X/postgres entry is a grant to PUBLIC
-- that anon inherits without ever being named.

ALTER FUNCTION public.trg_circle_join_notify() SECURITY DEFINER;

REVOKE ALL ON FUNCTION public.process_notification_event(
  uuid, text, text, uuid, uuid, text, text
) FROM PUBLIC;

REVOKE ALL ON FUNCTION public.process_notification_event(
  uuid, text, text, uuid, uuid, text, text
) FROM anon;

REVOKE ALL ON FUNCTION public.process_notification_event(
  uuid, text, text, uuid, uuid, text, text
) FROM authenticated;

COMMENT ON FUNCTION public.process_notification_event(
  uuid, text, text, uuid, uuid, text, text
) IS
'KAN-182. NOT REACHABLE BY ANY CLIENT ROLE: EXECUTE is held only by postgres '
'and service_role. p_to_user_id is an arbitrary delivery target, p_title and '
'p_body are arbitrary text, and p_entity_id becomes the action_route deep '
'link -- together an in-app phishing primitive if any untrusted role can call '
'it. The parameters are RETAINED deliberately: the body templates title from '
'p_kind_key and the overrides are used by legitimate internal callers, so the '
'control is reachability, not parameter removal. Callers must be SECURITY '
'DEFINER owned by a role holding EXECUTE; a SECURITY INVOKER caller will '
'raise 42501 for an end user. Admin free-text broadcast is a separate, '
'separately authorized path: rpc_broadcast_inapp_notification via the '
'broadcast-notification edge function behind is_admin().';