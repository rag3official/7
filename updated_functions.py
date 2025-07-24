def get_or_create_driver_profile(user_id: str, user_info: dict) -> dict:
    """Get or create a driver profile for a Slack user."""
    try:
        # Try to get existing driver profile
        result = supabase.table('driver_profiles').select('*').eq('slack_user_id', user_id).execute()
        
        if result.data and len(result.data) > 0:
            return result.data[0]
        
        # Get user's real name from Slack profile
        real_name = user_info.get('real_name', user_info.get('name', 'Unknown Driver'))
        email = user_info.get('profile', {}).get('email', '')
        phone = user_info.get('profile', {}).get('phone', '')
        
        # Create new driver profile if it doesn't exist
        new_driver = {
            'slack_user_id': user_id,
            'slack_username': user_info.get('name', ''),
            'name': real_name,  # Required
            'license_number': f'TEMP-{user_id}',  # Required - temporary
            'license_expiry': (datetime.now() + timedelta(days=30)).date().isoformat(),  # Required - temporary 30 days
            'phone_number': phone if phone else '000-000-0000',  # Required
            'email': email if email else f'{user_id}@example.com',  # Optional but good to have
            'status': 'active',  # One of: active, inactive, on_leave
            'certifications': [],  # Optional array
            'additional_info': {  # Optional JSONB
                'needs_update': True,
                'temporary_profile': True,
                'created_from_slack': True
            },
            'created_at': datetime.now().isoformat(),
            'updated_at': datetime.now().isoformat()
        }
        
        create_result = supabase.table('driver_profiles').insert(new_driver).execute()
        
        if not create_result.data:
            raise Exception("Failed to create driver profile")
            
        logger.info(f"Created new driver profile for {real_name} (Slack ID: {user_id})")
        return create_result.data[0]
        
    except Exception as e:
        logger.error(f"Error in get_or_create_driver_profile: {e}")
        raise

def upload_to_supabase_storage(image_data: bytes, van_number: str, filename: str, user_id: str = None, user_info: dict = None) -> dict:
    """Upload image to Supabase Storage and create van_images record."""
    try:
        logger.info(f"Uploading image to Supabase Storage: {filename}")
        
        # Calculate image hash first
        image_hash = hashlib.sha256(image_data).hexdigest()
        
        # Get van ID from van number
        van_result = supabase.table('vans').select('id').eq('van_number', van_number).execute()
        if not van_result.data:
            logger.error(f"Van not found with number: {van_number}")
            return None
            
        van_id = van_result.data[0]['id']
        
        # Check if we already have this image for this van
        existing_images = supabase.table('van_images').select('*').eq('van_id', van_id).eq('image_hash', image_hash).execute()
        
        if existing_images.data:
            logger.info(f"Image with hash {image_hash} already exists for van {van_number}")
            return {
                'url': existing_images.data[0]['image_url'],
                'image_hash': image_hash,
                'van_id': van_id,
                'image_record': existing_images.data[0]
            }
        
        # If image doesn't exist, proceed with upload
        bucket_name = "van-images"
        file_path = f"van_{van_number}/{filename}"
        
        # Upload the file
        result = supabase.storage.from_(bucket_name).upload(
            file_path,
            image_data,
            {"content-type": mimetypes.guess_type(filename)[0] or 'image/jpeg'}
        )
        
        if not result:
            logger.error("Failed to upload image")
            return None
            
        # Get public URL
        public_url = supabase.storage.from_(bucket_name).get_public_url(file_path)
        logger.info(f"Successfully uploaded image: {public_url}")
        
        # Create van_images record
        image_data = {
            'van_id': van_id,
            'image_url': public_url,
            'image_hash': image_hash,
            'damage_level': 0,  # Will be updated by damage assessment
            'status': 'active',
            'original_format': mimetypes.guess_type(filename)[0] or 'image/jpeg',
            'original_size_bytes': len(image_data),
            'created_at': datetime.now().isoformat()
        }
        
        image_result = supabase.table('van_images').insert(image_data).execute()
        if not image_result.data:
            logger.error("Failed to create van_images record")
            return None
            
        # If user info is provided, create driver profile and link image
        if user_id and user_info:
            try:
                # Get or create driver profile
                driver_profile = get_or_create_driver_profile(user_id, user_info)
                
                # Create driver image record
                driver_image = save_driver_image(
                    driver_id=driver_profile['id'],
                    van_id=van_id,
                    van_image_id=image_result.data[0]['id']
                )
                
                # Create van assignment if it doesn't exist
                assign_van_to_driver(van_id, driver_profile['id'])
                
                logger.info(f"Created driver image record: {driver_image['id']}")
            except Exception as e:
                logger.error(f"Error creating driver records: {str(e)}")
            
        logger.info(f"Created van_images record: {image_result.data[0]['id']}")
        return {
            'url': public_url,
            'image_hash': image_hash,
            'van_id': van_id,
            'image_record': image_result.data[0]
        }
        
    except Exception as e:
        logger.error(f"Error in upload_to_supabase_storage: {str(e)}")
        return None 