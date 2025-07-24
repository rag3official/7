import os
import sys
import glob
from typing import List
import psycopg2
from dotenv import load_dotenv
import logging

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def get_sql_files(migrations_dir: str) -> List[str]:
    """Get all .sql files from the migrations directory in sorted order."""
    sql_pattern = os.path.join(migrations_dir, '*.sql')
    return sorted(glob.glob(sql_pattern))

def execute_migration(cursor, sql_file: str) -> bool:
    """Execute a single migration file."""
    try:
        with open(sql_file, 'r') as f:
            sql = f.read()
            
        logger.info(f"Executing migration: {os.path.basename(sql_file)}")
        cursor.execute(sql)
        return True
    except Exception as e:
        logger.error(f"Error executing {sql_file}: {str(e)}")
        return False

def main():
    # Load environment variables
    load_dotenv()
    
    # Get database connection details from environment
    db_url = os.getenv('SUPABASE_DB_URL')
    if not db_url:
        logger.error("SUPABASE_DB_URL environment variable not set")
        return False
    
    try:
        # Connect to the database
        conn = psycopg2.connect(db_url)
        conn.autocommit = False
        cursor = conn.cursor()
        
        # Get all SQL files
        migrations_dir = os.path.join(os.path.dirname(__file__), 'sql')
        sql_files = get_sql_files(migrations_dir)
        
        if not sql_files:
            logger.warning("No SQL migration files found")
            return True
            
        # Execute each migration in a transaction
        for sql_file in sql_files:
            try:
                if not execute_migration(cursor, sql_file):
                    conn.rollback()
                    return False
                conn.commit()
                logger.info(f"Successfully applied migration: {os.path.basename(sql_file)}")
            except Exception as e:
                conn.rollback()
                logger.error(f"Failed to apply migration {sql_file}: {str(e)}")
                return False
                
        logger.info("All migrations completed successfully!")
        return True
        
    except Exception as e:
        logger.error(f"Database connection error: {str(e)}")
        return False
    finally:
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 