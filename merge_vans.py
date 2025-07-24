#!/usr/bin/env python3
import csv
import re

INPUT_FILE = '/Users/prolix/7/supabase_ready.csv'
OUTPUT_FILE = '/Users/prolix/7/supabase_merged.csv'

def standardize_van_number(van_number):
    """Standardize van number format to ensure consistent matching"""
    # Remove any suffix like _1, _2 that might have been added
    van_number = re.sub(r'_\d+$', '', van_number)
    # Remove any extra spaces
    van_number = van_number.strip()
    # Replace spaces with underscores
    van_number = van_number.replace(' ', '_')
    return van_number

def main():
    # Read the CSV file
    with open(INPUT_FILE, 'r', encoding='utf-8') as file:
        reader = csv.reader(file)
        header = next(reader)
        rows = list(reader)
    
    # Group rows by standardized van number
    van_groups = {}
    for row in rows:
        if not row or len(row) < 10:  # Skip invalid rows
            continue
            
        std_van_number = standardize_van_number(row[0])
        if std_van_number not in van_groups:
            van_groups[std_van_number] = []
        van_groups[std_van_number].append(row)
    
    # Merge duplicate entries
    merged_rows = []
    duplicates_found = 0
    
    for van_number, group in van_groups.items():
        if len(group) > 1:
            duplicates_found += 1
            print(f"Merging {len(group)} entries for {van_number}")
            
            # Start with the first entry but use the standardized van number
            merged_row = group[0].copy()
            merged_row[0] = van_number  # Use clean van number without suffixes
            
            # Merge data from other entries
            for other_row in group[1:]:
                # For each field, keep non-empty values (preference to later entries)
                for i in range(1, len(header)):
                    if i < len(other_row) and other_row[i].strip():
                        # Special handling for notes, damage, damage_description fields
                        if i in [5, 8, 9]:  # These are indexes for notes, damage, damage_description
                            if merged_row[i].strip() and other_row[i].strip() not in merged_row[i]:
                                merged_row[i] = f"{merged_row[i]} | {other_row[i]}"
                            elif other_row[i].strip():
                                merged_row[i] = other_row[i]
                        else:
                            # For other fields, later entries overwrite earlier ones if not empty
                            merged_row[i] = other_row[i]
            
            merged_rows.append(merged_row)
        else:
            # No duplicates, just add the single entry with standardized van number
            single_row = group[0].copy()
            single_row[0] = van_number  # Ensure clean van number
            merged_rows.append(single_row)
    
    # Write the merged data
    with open(OUTPUT_FILE, 'w', newline='', encoding='utf-8') as file:
        writer = csv.writer(file)
        writer.writerow(header)
        writer.writerows(merged_rows)
    
    print(f"Found and merged {duplicates_found} van profiles")
    print(f"Saved merged CSV to {OUTPUT_FILE}")
    print(f"Original entries: {len(rows)}, Merged entries: {len(merged_rows)}")

if __name__ == "__main__":
    main() 