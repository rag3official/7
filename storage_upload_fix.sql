-- Storage Upload Fix for Slack Bot
-- This function allows system uploads without user_id constraints

-- Function to create storage objects without user constraints
CREATE OR REPLACE FUNCTION create_storage_object(
    bucket_id text,
    name text,
    owner uuid DEFAULT NULL,
    user_id uuid DEFAULT NULL
)
RETURNS void
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Insert into objects table bypassing constraints for system uploads
    INSERT INTO storage.objects (bucket_id, name, owner, owner_id, user_metadata, version)
    VALUES (bucket_id, name, owner, user_id, '{}', gen_random_uuid()::text)
    ON CONFLICT (bucket_id, name) 
    DO UPDATE SET version = gen_random_uuid()::text;
    
    -- Ensure no rate limit entry is created for system uploads
    DELETE FROM storage.upload_rate_limits 
    WHERE bucket_id = create_storage_object.bucket_id 
    AND object_name = create_storage_object.name
    AND user_id IS NULL;
END;
$$;

-- Function for system image uploads (alternative approach)
CREATE OR REPLACE FUNCTION system_upload_image(
    bucket_name text,
    file_path text,
    file_data text,
    content_type text DEFAULT 'image/jpeg'
)
RETURNS text
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
    object_id uuid;
    public_url text;
BEGIN
    -- Create the storage object record
    INSERT INTO storage.objects (
        bucket_id, 
        name, 
        owner, 
        owner_id, 
        metadata,
        user_metadata,
        version
    )
    VALUES (
        bucket_name,
        file_path,
        NULL,
        NULL,
        jsonb_build_object('size', length(decode(file_data, 'base64')), 'mimetype', content_type),
        '{}',
        gen_random_uuid()::text
    )
    ON CONFLICT (bucket_id, name) 
    DO UPDATE SET 
        metadata = jsonb_build_object('size', length(decode(file_data, 'base64')), 'mimetype', content_type),
        version = gen_random_uuid()::text
    RETURNING id INTO object_id;
    
    -- Skip rate limit checks for system uploads
    -- Don't insert into upload_rate_limits table
    
    -- Return the public URL
    public_url := concat(
        current_setting('app.settings.supabase_url', true),
        '/storage/v1/object/public/',
        bucket_name,
        '/',
        file_path
    );
    
    RETURN public_url;
END;
$$;

-- Grant execute permissions to service role
GRANT EXECUTE ON FUNCTION create_storage_object TO service_role;
GRANT EXECUTE ON FUNCTION system_upload_image TO service_role;

-- Temporarily disable rate limiting for specific bucket (if needed)
-- UPDATE storage.buckets 
-- SET public = true, 
--     file_size_limit = 52428800, -- 50MB
--     allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
-- WHERE id = 'van-images';

-- Alternative: Create a service user to avoid NULL user_id issues
DO $$
DECLARE
    service_user_id uuid;
BEGIN
    -- Create a system service user if it doesn't exist
    INSERT INTO auth.users (
        id,
        aud,
        role,
        email,
        email_confirmed_at,
        created_at,
        updated_at,
        raw_app_meta_data,
        raw_user_meta_data,
        is_super_admin
    )
    VALUES (
        'a0000000-0000-4000-8000-000000000000'::uuid,
        'authenticated',
        'service_role',
        'slack-bot@system.local',
        now(),
        now(),
        now(),
        '{"provider": "system", "providers": ["system"]}',
        '{"name": "Slack Bot System User"}',
        false
    )
    ON CONFLICT (id) DO NOTHING;
    
EXCEPTION
    WHEN OTHERS THEN
        -- If auth schema doesn't allow this, skip silently
        NULL;
END $$; 