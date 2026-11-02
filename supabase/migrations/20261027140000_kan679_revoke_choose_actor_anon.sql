-- KAN-679: revoke EXECUTE on choose_actor from PUBLIC and anon. REVOKE only (cto ruling P2, 2026-10-27).
-- authenticated and service_role keep their existing EXECUTE. The function body is not changed.
REVOKE ALL ON FUNCTION public.choose_actor(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.choose_actor(text) FROM anon;
