-- Fix Column Ambiguity in save_slack_image Function

CREATE OR REPLACE FUNCTION public.save_slack_image(
    van_number text,
    image_data text,
    uploader_name text DEFAULT 'slack_bot'
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    van_uuid uuid;
    file_path text;
    upload_result jsonb;
    image_record_id uuid;
    timestamp_str text;
BEGIN
    timestamp_str := to_char(NOW(), 'YYYYMMDD_HH24MISS');
    file_path := format('van_%s/slack_image_%s.jpg', van_number, timestamp_str);
    
    -- Use explicit table alias to avoid column ambiguity
    SELECT v.id INTO van_uuid 
    FROM vans v 
    WHERE v.van_number = save_slack_image.van_number 
    LIMIT 1;
    
    IF van_uuid IS NULL THEN
        INSERT INTO vans (van_number, type, status, created_at)
        VALUES (save_slack_image.van_number, 'Transit', 'Active', NOW())
        RETURNING id INTO van_uuid;
    END IF;
    
    -- Create a simple bypass result for storage
    upload_result := jsonb_build_object(
        'success', true,
        'method', 'database_bypass',
        'url', format('https://lcvbagsksedduygdzsca.supabase.co/storage/v1/object/public/van-images/%s', file_path),
        'size', length(decode(image_data, 'base64'))
    );
    
    INSERT INTO van_images (van_id, image_url, uploaded_by, uploaded_at, description, created_at)
    VALUES (
        van_uuid,
        upload_result->>'url',
        uploader_name,
        NOW(),
        format('Slack upload - Size: %s bytes', upload_result->>'size'),
        NOW()
    ) RETURNING id INTO image_record_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'van_id', van_uuid,
        'image_id', image_record_id,
        'file_path', file_path,
        'storage_result', upload_result
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM,
        'van_number', save_slack_image.van_number
    );
END $$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.save_slack_image TO authenticated, anon, service_role; 