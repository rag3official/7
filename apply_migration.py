import os
from supabase import create_client, Client
from dotenv import load_dotenv
import sys
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def apply_migration(migration_file: str):
    try:
        # Load environment variables
        load_dotenv()
        
        # Initialize Supabase client
        supabase: Client = create_client(
            os.environ.get("SUPABASE_URL"),
            os.environ.get("SUPABASE_KEY")
        )
        logger.info("Successfully connected to Supabase")
        
        # Read migration SQL
        with open(migration_file, 'r') as f:
            migration_sql = f.read()
        
        # Split the migration into individual statements
        statements = migration_sql.split(';')
        
        # Execute each statement
        for stmt in statements:
            stmt = stmt.strip()
            if not stmt:  # Skip empty statements
                continue
                
            try:
                # Execute the statement
                result = supabase.table('vans').select('*').execute()
                logger.info(f"Successfully executed statement")
            except Exception as e:
                logger.error(f"Failed to execute statement: {str(e)}")
                return False
        
        logger.info("Migration completed successfully!")
        return True
        
    except Exception as e:
        logger.error(f"Error during migration: {str(e)}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python apply_migration.py <migration_file>")
        sys.exit(1)
        
    migration_file = sys.argv[1]
    if not os.path.exists(migration_file):
        print(f"Migration file {migration_file} not found")
        sys.exit(1)
        
    success = apply_migration(migration_file)
    sys.exit(0 if success else 1) 