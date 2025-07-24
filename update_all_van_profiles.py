#!/usr/bin/env python3
"""
Update ALL van profiles with damage rating information from their images
"""

import os
import sys
from datetime import datetime
from dotenv import load_dotenv
from supabase import create_client

def main():
    # Load environment variables
    load_dotenv()
    
    # Initialize Supabase
    supabase_url = os.environ.get("SUPABASE_URL")
    supabase_key = os.environ.get("SUPABASE_KEY")
    
    if not supabase_url or not supabase_key:
        print("❌ Missing SUPABASE_URL or SUPABASE_KEY")
        return False
    
    supabase = create_client(supabase_url, supabase_key)
    print("✅ Connected to Supabase")
    
    try:
        # Get all vans
        print("🔍 Fetching all vans...")
        vans_response = supabase.table("van_profiles").select("id, van_number, make, model").execute()
        
        if not vans_response.data:
            print("❌ No vans found")
            return False
        
        print(f"📊 Found {len(vans_response.data)} vans to process")
        updated_count = 0
        
        for van in vans_response.data:
            van_id = van['id']
            van_number = van['van_number']
            current_make = van.get('make')
            current_model = van.get('model')
            
            print(f"\n🚐 Processing Van #{van_number}")
            print(f"   Current: Make='{current_make}', Model='{current_model}'")
            
            # Get all images for this van to calculate damage rating
            images_response = supabase.table("van_images").select(
                "van_rating, damage_type, damage_severity, van_damage"
            ).eq("van_id", van_id).execute()
            
            if not images_response.data:
                print(f"   ⚠️ No images found - setting default")
                # Set default for vans with no images
                update_data = {
                    "make": "Enterprise",
                    "model": "Rental Van - No Damage Reported",
                    "updated_at": datetime.now().isoformat()
                }
            else:
                # Calculate damage rating from images
                max_rating = 0
                damage_types = set()
                all_damage_text = []
                
                for img in images_response.data:
                    rating = img.get('van_rating') or 0
                    max_rating = max(max_rating, rating)
                    
                    if img.get('damage_type') and img['damage_type'] != 'unknown':
                        damage_types.add(img['damage_type'])
                    
                    if img.get('van_damage'):
                        all_damage_text.append(img['van_damage'])
                
                # Create rating description
                rating_descriptions = {
                    0: "No Damage",
                    1: "Minor (Dirt/Debris)",
                    2: "Moderate (Scratches)", 
                    3: "Major (Dents/Damage)"
                }
                
                rating_desc = rating_descriptions.get(max_rating, "Unknown")
                damage_types_str = ", ".join([dt for dt in damage_types if dt and dt != 'unknown'])
                
                if damage_types_str:
                    model_text = f"Rental Van - {rating_desc} - {damage_types_str}"
                else:
                    model_text = f"Rental Van - {rating_desc} (Level {max_rating}/3)"
                
                update_data = {
                    "make": "Enterprise",
                    "model": model_text,
                    "updated_at": datetime.now().isoformat()
                }
                
                print(f"   📊 Max Rating: {max_rating}, Types: {damage_types_str or 'none'}")
                print(f"   🎯 New Model: '{model_text}'")
            
            # Perform the update
            try:
                response = supabase.table("van_profiles").update(update_data).eq("id", van_id).execute()
                
                if response.data:
                    print(f"   ✅ Updated successfully")
                    updated_count += 1
                else:
                    print(f"   ❌ Update failed - no data returned")
                    
            except Exception as e:
                print(f"   ❌ Update error: {e}")
        
        print(f"\n🎉 Completed! Updated {updated_count}/{len(vans_response.data)} vans")
        return True
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 