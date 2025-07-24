-- Create a function to run migrations
CREATE OR REPLACE FUNCTION run_migration(sql text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    EXECUTE sql;
    RETURN 'Migration successful';
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'error', SQLERRM,
            'detail', SQLSTATE
        )::text;
END;
$$; 