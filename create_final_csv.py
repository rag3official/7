import csv
import re
import os

# File paths
input_file = 'unique_vans.csv'
output_file = 'final_vans.csv'

# Function to standardize van numbers
def standardize_van_number(van_number):
    # Replace space with underscore
    van_number = van_number.replace(' ', '_')
    
    # Remove suffix pattern like _1, _2
    base_number = re.sub(r'_[0-9]+$', '', van_number)
    
    # Extract and zero-pad numeric part for van_X format
    match = re.match(r'^(van_)(\d+)$', base_number)
    if match:
        prefix, number = match.groups()
        return f"{prefix}{number.zfill(2)}"
    
    return base_number

# Read the entire file as text first to handle line breaks
print(f"Reading {input_file}...")
with open(input_file, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix line breaks in URLs
content = re.sub(r'(https?://[^\s,]+)\n([^\s,]+)', r'\1\2', content)
content = re.sub(r'(drive\.google\.com[^\s,]+)\n([^\s,]+)', r'\1\2', content)

# Read the fixed content as CSV
cleaned_data = {}
headers = content.split('\n')[0].split(',')

rows = []
for line in content.split('\n')[1:]:
    if not line.strip():
        continue
    
    # Split the line into fields, handling commas in quoted fields
    fields = []
    in_quotes = False
    current_field = ""
    
    for char in line + ',':  # Add comma to handle last field
        if char == '"':
            in_quotes = not in_quotes
            current_field += char
        elif char == ',' and not in_quotes:
            fields.append(current_field)
            current_field = ""
        else:
            current_field += char
    
    # Create a dictionary for this row
    if len(fields) == len(headers):
        row = dict(zip(headers, fields))
        rows.append(row)
    else:
        print(f"Warning: Skipping row with {len(fields)} fields (expected {len(headers)}): {line[:50]}...")

# Process each row for deduplication
total_rows = len(rows)
for row in rows:
    # Skip rows without a van number
    if not row['van_number']:
        continue
    
    # Standardize the van number
    standard_number = standardize_van_number(row['van_number'])
    
    # Clean all values (remove quotes, line breaks)
    for field in row:
        if row[field]:
            # Remove quotes and line breaks
            row[field] = row[field].replace('"', '').replace('\n', ' ').strip()
    
    # If this is a new van, add it to our dictionary
    if standard_number not in cleaned_data:
        cleaned_data[standard_number] = row.copy()
        cleaned_data[standard_number]['van_number'] = standard_number
    else:
        # Merge with existing data, keeping the best values
        existing = cleaned_data[standard_number]
        
        # Use non-default values when available
        if row['type'] and row['type'] != 'Unknown' and (not existing['type'] or existing['type'] == 'Unknown'):
            existing['type'] = row['type']
            
        if row['status'] and row['status'] != 'Active' and (not existing['status'] or existing['status'] == 'Active'):
            existing['status'] = row['status']
            
        # Use non-empty values when available
        for field in ['date', 'last_updated', 'url', 'driver']:
            if field in row and field in existing and row[field] and not existing[field]:
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
        
        # Use the highest rating if available
        if 'rating' in row and 'rating' in existing and row['rating']:
            try:
                existing_rating = float(existing['rating'] or 0)
                new_rating = float(row['rating'] or 0)
                if new_rating > existing_rating:
                    existing['rating'] = row['rating']
            except (ValueError, TypeError):
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

# Create a verification file with just a few records for testing
with open('test_import.csv', 'w', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=headers)
    writer.writeheader()
    
    # Take just first 5 records for testing
    for van_number in list(sorted(cleaned_data.keys()))[:5]:
        writer.writerow(cleaned_data[van_number])

print(f"Also created test_import.csv with 5 test records for verification before full import.") 