-- First promote the real user to admin
INSERT INTO public.admin_users (id, created_by)
VALUES ('123e4567-e89b-12d3-a456-426614174000'::uuid, '123e4567-e89b-12d3-a456-426614174000'::uuid)
ON CONFLICT (id) DO NOTHING;

-- Then remove the temporary admin if we have at least one other admin
DELETE FROM public.admin_users 
WHERE id = '00000000-0000-0000-0000-000000000000'::uuid
AND EXISTS (
  SELECT 1 FROM public.admin_users 
  WHERE id != '00000000-0000-0000-0000-000000000000'::uuid
); 