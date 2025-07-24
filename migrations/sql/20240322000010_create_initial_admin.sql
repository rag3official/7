BEGIN;

-- Insert a temporary admin if no admins exist
INSERT INTO public.admin_users (id, created_by)
SELECT 
  '00000000-0000-0000-0000-000000000000'::UUID,
  '00000000-0000-0000-0000-000000000000'::UUID
WHERE NOT EXISTS (SELECT 1 FROM public.admin_users);

COMMIT; 