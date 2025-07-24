import csv
import re
import os

# File paths
input_file = 'cleaned_vans.csv'
output_file = 'import_ready.csv'

# Function to fix line breaks in URLs and other fields
def fix_line_breaks(text):
    if not text:
        return ""
    # Remove actual line breaks in text
    text = text.replace('\n', ' ')
    # Fix quoted text with line breaks
    text = re.sub(r'"([^"]*)"', lambda m: m.group(1).replace('\n', ' '), text)
    return text

# Read the cleaned CSV and fix any remaining issues
print(f"Reading {input_file}...")
rows = []
with open(input_file, 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    headers = reader.fieldnames
    
    for row in reader:
        # Fix line breaks in all fields
        for field in row:
            if row[field]:
                row[field] = fix_line_breaks(row[field])
        
        # Ensure numeric fields are valid
        if 'rating' in row and row['rating']:
            # Clean up ratings that might have extra text
            rating_match = re.search(r'(\d+(\.\d+)?)', row['rating'])
            if rating_match:
                row['rating'] = rating_match.group(1)
            else:
                row['rating'] = "0"
        
        # Add the fixed row
        rows.append(row)

# Write the final cleaned data to the output file
print(f"Writing {output_file}...")
with open(output_file, 'w', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=headers)
    writer.writeheader()
    
    for row in rows:
        writer.writerow(row)

print(f"Done! Created final import-ready CSV with {len(rows)} van records.")
print(f"Output saved to {output_file}")

# Create a backup of the original file just in case
if os.path.exists('unique_vans.csv.bak'):
    print("Backup of original file already exists.")
else:
    with open('unique_vans.csv', 'r', encoding='utf-8') as src:
        with open('unique_vans.csv.bak', 'w', encoding='utf-8') as dst:
            dst.write(src.read())
    print("Created backup of original file as unique_vans.csv.bak") 