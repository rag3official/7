import os
from supabase import create_client, Client
from dotenv import load_dotenv
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def verify_migration():
    try:
        # Load environment variables
        load_dotenv()
        
        # Initialize Supabase client
        supabase: Client = create_client(
            os.environ.get("SUPABASE_URL"),
            os.environ.get("SUPABASE_KEY")
        )
        logger.info("Successfully connected to Supabase")
        
        # Check driver_profiles table
        logger.info("Checking driver_profiles table...")
        result = supabase.table('driver_profiles').select('*').limit(1).execute()
        logger.info("driver_profiles table exists")
        
        # Check driver_van_assignments table
        logger.info("Checking driver_van_assignments table...")
        result = supabase.table('driver_van_assignments').select('*').limit(1).execute()
        logger.info("driver_van_assignments table exists")
        
        # Check driver_images table
        logger.info("Checking driver_images table...")
        result = supabase.table('driver_images').select('*').limit(1).execute()
        logger.info("driver_images table exists")
        
        # Check views
        logger.info("Checking active_driver_assignments view...")
        result = supabase.from_('active_driver_assignments').select('*').limit(1).execute()
        logger.info("active_driver_assignments view exists")
        
        logger.info("Checking driver_image_summary view...")
        result = supabase.from_('driver_image_summary').select('*').limit(1).execute()
        logger.info("driver_image_summary view exists")
        
        logger.info("Migration verification completed successfully!")
        return True
        
    except Exception as e:
        logger.error(f"Error during verification: {str(e)}")
        return False

if __name__ == "__main__":
    success = verify_migration()
    exit(0 if success else 1) 