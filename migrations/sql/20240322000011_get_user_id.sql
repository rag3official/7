-- Get all users and their IDs
SELECT id::text, email, created_at
FROM auth.users
ORDER BY created_at DESC; 