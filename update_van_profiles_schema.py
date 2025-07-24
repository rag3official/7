#!/usr/bin/env python3
"""
Update van_profiles table with damage rating columns and populate with aggregated data
"""

import os
import sys
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
        # Get all vans and their images to calculate ratings
        print("🔍 Fetching all vans and their damage data...")
        
        vans_response = supabase.table("van_profiles").select("id, van_number").execute()
        
        if not vans_response.data:
            print("❌ No vans found")
            return False
        
        print(f"📊 Found {len(vans_response.data)} vans to process")
        
        for van in vans_response.data:
            van_id = van['id']
            van_number = van['van_number']
            
            print(f"\n🚐 Processing Van #{van_number} (ID: {van_id})")
            
            # Get all images for this van
            images_response = supabase.table("van_images").select(
                "van_rating, van_damage, damage_type, damage_severity, van_side"
            ).eq("van_id", van_id).execute()
            
            if not images_response.data:
                print(f"  ⚠️ No images found for van {van_number}")
                continue
            
            # Calculate aggregated damage data
            max_rating = 0
            damage_descriptions = []
            damage_types = set()
            severities = set()
            sides = set()
            
            for img in images_response.data:
                rating = img.get('van_rating') or 0
                max_rating = max(max_rating, rating)
                
                if img.get('van_damage'):
                    damage_descriptions.append(img['van_damage'])
                
                if img.get('damage_type'):
                    damage_types.add(img['damage_type'])
                
                if img.get('damage_severity'):
                    severities.add(img['damage_severity'])
                
                if img.get('van_side'):
                    sides.add(img['van_side'])
            
            # Create aggregated description
            overall_damage = "Multiple damage types reported" if len(damage_descriptions) > 1 else (damage_descriptions[0] if damage_descriptions else "No damage reported")
            
            # Determine overall condition
            condition_map = {
                0: "excellent",
                1: "good", 
                2: "fair",
                3: "poor"
            }
            overall_condition = condition_map.get(max_rating, "unknown")
            
            print(f"  📊 Max Rating: {max_rating}, Condition: {overall_condition}")
            print(f"  📋 Damage Types: {', '.join(damage_types) if damage_types else 'none'}")
            print(f"  📍 Sides Photographed: {', '.join(sides) if sides else 'none'}")
            
            # Update van profile with aggregated damage data
            update_data = {
                "notes": f"Overall damage rating: {max_rating}/3. Condition: {overall_condition}. Damage types: {', '.join(damage_types) if damage_types else 'none'}. Sides photographed: {', '.join(sides) if sides else 'none'}."
            }
            
            # Try to update with damage columns if they exist
            try:
                # First, try a test update to see if damage columns exist
                test_response = supabase.table("van_profiles").select("damage_level, damage_description, overall_condition").limit(1).execute()
                
                # If we get here, columns exist, so include them in update
                update_data.update({
                    "damage_level": max_rating,
                    "damage_description": overall_damage,
                    "overall_condition": overall_condition
                })
                print(f"  ✅ Will update with damage columns")
                
            except Exception as e:
                print(f"  ⚠️ Damage columns don't exist in van_profiles, using notes only")
            
            # Perform the update
            try:
                update_response = supabase.table("van_profiles").update(update_data).eq("id", van_id).execute()
                
                if update_response.data:
                    print(f"  ✅ Updated van {van_number} successfully")
                else:
                    print(f"  ❌ Failed to update van {van_number}")
                    
            except Exception as e:
                print(f"  ❌ Error updating van {van_number}: {e}")
        
        print(f"\n🎉 Completed processing all vans!")
        return True
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 