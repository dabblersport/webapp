-- KAN-700 rollback: drops only the function this ticket added.
DROP FUNCTION IF EXISTS public.rpc_admin_launch_funnel(date, date);
