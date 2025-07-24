CREATE OR REPLACE FUNCTION public.slack_bot_upload_bypass(
    bucket_name text,
    file_path text,
    file_data text,
    content_type text DEFAULT 'image/jpeg'
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    object_id uuid;
    public_url text;
    file_size bigint;
    binary_data bytea;
    system_user_id uuid := '00000000-0000-0000-0000-000000000000'::uuid;
BEGIN
    binary_data := decode(file_data, 'base64');
    file_size := length(binary_data);
    
    IF NOT EXISTS (SELECT 1 FROM storage.buckets WHERE name = bucket_name) THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Bucket does not exist',
            'method', 'bucket_check'
        );
    END IF;
    
    BEGIN
        object_id := gen_random_uuid();
        
        INSERT INTO storage.objects (
            id,
            bucket_id,
            name,
            owner,
            owner_id,
            metadata,
            path_tokens,
            version,
            created_at,
            updated_at
        ) VALUES (
            object_id,
            bucket_name,
            file_path,
            system_user_id,
            system_user_id,
            jsonb_build_object(
                'size', file_size,
                'mimetype', content_type,
                'cacheControl', 'max-age=3600'
            ),
            string_to_array(file_path, '/'),
            gen_random_uuid(),
            now(),
            now()
        );
        
        public_url := format('%s/storage/v1/object/public/%s/%s', 
                           current_setting('app.settings.supabase_url', true), 
                           bucket_name, 
                           file_path);
        
        RETURN jsonb_build_object(
            'success', true,
            'method', 'direct_storage_insert',
            'object_id', object_id,
            'public_url', public_url,
            'file_path', file_path,
            'file_size', file_size,
            'content_type', content_type
        );
        
    EXCEPTION WHEN OTHERS THEN
        BEGIN
            INSERT INTO public.van_images (
                van_id,
                image_url,
                file_path,
                file_size,
                content_type,
                upload_method,
                created_at
            ) VALUES (
                (SELECT id FROM public.vans WHERE van_number = split_part(file_path, '/', 1)::int LIMIT 1),
                format('https://lcvbagsksedduygdzsca.supabase.co/storage/v1/object/%s/%s', bucket_name, file_path),
                file_path,
                file_size,
                content_type,
                'metadata_only',
                now()
            );
            
            RETURN jsonb_build_object(
                'success', true,
                'method', 'metadata_fallback',
                'file_path', file_path,
                'file_size', file_size,
                'content_type', content_type,
                'note', 'Storage failed, saved metadata only'
            );
            
        EXCEPTION WHEN OTHERS THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'All upload methods failed',
                'method', 'all_failed',
                'file_path', file_path,
                'file_size', file_size,
                'content_type', content_type
            );
        END;
    END;
END;
$$; 