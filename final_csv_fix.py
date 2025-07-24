import csv
import re
import os

# File paths
input_file = 'unique_vans.csv'
output_file = 'supabase_import.csv'

# Read the entire file content as a single string
print(f"Reading {input_file}...")
with open(input_file, 'r', encoding='utf-8') as f:
    content = f.read()

# Pre-process the content to handle line breaks in URLs and fields
# First, replace all line breaks within URL fields
content = re.sub(r'(https?://\S+)\s*\n\s*(\S+)', r'\1 \2', content)
content = re.sub(r'(drive\.google\.com\S+)\s*\n\s*(\S+)', r'\1 \2', content)

# Function to standardize van numbers
def standardize_van_number(van_number):
    if not van_number:
        return van_number
        
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

# Process the data line by line
lines = content.split('\n')
headers = lines[0].split(',')
raw_rows = []

# First, combine lines that are part of the same record
i = 1  # Start from line after header
while i < len(lines):
    line = lines[i].strip()
    
    # Skip empty lines
    if not line:
        i += 1
        continue
    
    # If line starts with 'van' or 'slack', it's a new record
    if re.match(r'^(van|slack)', line, re.IGNORECASE):
        raw_rows.append(line)
    else:
        # This line is a continuation of the previous record
        if raw_rows:
            raw_rows[-1] += " " + line
    
    i += 1

# Now process each raw row into fields
cleaned_data = {}
for raw_row in raw_rows:
    fields = raw_row.split(',')
    
    # Ensure we have enough fields
    if len(fields) < len(headers):
        fields.extend([''] * (len(headers) - len(fields)))
    elif len(fields) > len(headers):
        # Too many fields - try to fix by combining extra fields
        extra = ','.join(fields[len(headers):])
        fields = fields[:len(headers)-1] + [fields[len(headers)-1] + "," + extra]
    
    row = dict(zip(headers, fields))
    
    # Skip rows without a van number
    if not row['van_number']:
        continue
        
    # Standardize the van number
    original_number = row['van_number']
    standard_number = standardize_van_number(original_number)
    
    # Clean all values (remove quotes, line breaks)
    for field in row:
        if row[field]:
            # Clean up the text
            row[field] = row[field].replace('\n', ' ').replace('""', '"')
            # Remove surrounding quotes
            row[field] = re.sub(r'^\s*"(.*)"\s*$', r'\1', row[field])
            row[field] = row[field].strip()
    
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

# Write the cleaned data to output file
print(f"Writing {output_file}...")
with open(output_file, 'w', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=headers)
    writer.writeheader()
    
    # Sort by van_number for easier viewing
    for van_number in sorted(cleaned_data.keys()):
        writer.writerow(cleaned_data[van_number])

# Print summary
print(f"Done! Created {len(cleaned_data)} unique van records.")
print(f"Output saved to {output_file}")

# Create a test file with 3 records for verification
with open('test_import_final.csv', 'w', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=headers)
    writer.writeheader()
    
    test_count = min(3, len(cleaned_data))
    for van_number in list(sorted(cleaned_data.keys()))[:test_count]:
        writer.writerow(cleaned_data[van_number])

print(f"Also created test_import_final.csv with {test_count} test records for verification.") 