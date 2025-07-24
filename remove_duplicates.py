import csv
import re
import os

# File paths
input_file = 'unique_vans.csv'
output_file = 'cleaned_vans.csv'

# Dictionary to store the cleaned data
cleaned_data = {}

# Function to standardize van numbers
def standardize_van_number(van_number):
    # Remove suffix pattern like _1, _2
    base_number = re.sub(r'_[0-9]+$', '', van_number)
    
    # Replace space with underscore
    base_number = base_number.replace(' ', '_')
    
    # Extract and zero-pad numeric part for van_X format
    match = re.match(r'^(van_)(\d+)$', base_number)
    if match:
        prefix, number = match.groups()
        return f"{prefix}{number.zfill(2)}"
    
    return base_number

# Read the input CSV
print(f"Reading {input_file}...")
with open(input_file, 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    headers = reader.fieldnames
    total_rows = 0
    
    for row in reader:
        total_rows += 1
        # Standardize the van number
        original_number = row['van_number']
        standard_number = standardize_van_number(original_number)
        
        # If this is a new van, add it to our dictionary
        if standard_number not in cleaned_data:
            cleaned_data[standard_number] = row.copy()
            cleaned_data[standard_number]['van_number'] = standard_number
        else:
            # Otherwise, merge with existing data, keeping the best values
            existing = cleaned_data[standard_number]
            
            # Use non-default values when available
            if row['type'] != 'Unknown' and existing['type'] == 'Unknown':
                existing['type'] = row['type']
                
            if row['status'] != 'Active' and existing['status'] == 'Active':
                existing['status'] = row['status']
                
            # Use non-empty values when available
            for field in ['date', 'last_updated', 'url', 'driver']:
                if field in row and field in existing:
                    if row[field] and not existing[field]:
                        existing[field] = row[field]
            
            # Concatenate non-empty notes, damage, and damage_description
            for field in ['notes', 'damage', 'damage_description']:
                if field not in row or field not in existing:
                    continue
                    
                if row[field] and existing[field]:
                    if row[field] not in existing[field]:  # Avoid duplication
                        existing[field] = f"{existing[field]} | {row[field]}"
                elif row[field]:
                    existing[field] = row[field]
            
            # Use the highest rating if the field exists
            if 'rating' in row and 'rating' in existing:
                try:
                    existing_rating = float(existing['rating'] or 0)
                    new_rating = float(row['rating'] or 0)
                    if new_rating > existing_rating:
                        existing['rating'] = row['rating']
                except (ValueError, TypeError):
                    # If rating can't be converted to float, keep the existing one
                    pass

# Write the cleaned data to the output file
print(f"Writing {output_file}...")
with open(output_file, 'w', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=headers)
    writer.writeheader()
    
    # Sort by van_number for easier viewing
    for van_number in sorted(cleaned_data.keys()):
        writer.writerow(cleaned_data[van_number])

# Print summary
print(f"Done! Processed {total_rows} rows and created {len(cleaned_data)} unique van records.")
print(f"Removed {total_rows - len(cleaned_data)} duplicate entries.")
print(f"Output saved to {output_file}") 