import csv
import re
import os

# File paths
input_file = '/Users/prolix/7/Van Records - Sheet1-3.csv'
output_file = '/Users/prolix/7/completely_fixed_vans.csv'

# Read the entire file content to handle line breaks in fields
with open(input_file, 'r') as f:
    content = f.read()
    
# Replace problematic line breaks within URLs
content = re.sub(r'(https://[^\s,]+)\n([^\s,]+)', r'\1\2', content)
content = re.sub(r'(http://[^\s,]+)\n([^\s,]+)', r'\1\2', content)
content = re.sub(r'(drive.google.com[^\s,]+)\n([^\s,]+)', r'\1\2', content)

# Process the fixed content as CSV
lines = content.split('\n')
rows = [line.split(',') for line in lines if line.strip()]

with open(output_file, 'w', newline='') as outfile:
    writer = csv.writer(outfile)
    
    # Write header row
    writer.writerow(['van_number', 'type', 'status', 'date', 'last_updated', 
                    'notes', 'url', 'driver', 'damage', 'damage_description'])
    
    # Process each row
    for row in rows[1:]:  # Skip header
        if row and row[0].strip():  # Only include rows with van numbers
            # Ensure exactly 10 columns
            fixed_row = row[:10] if len(row) >= 10 else row + [''] * (10 - len(row))
            
            # Set default values for required fields
            if not fixed_row[1].strip():
                fixed_row[1] = 'Unknown'  # type
            if not fixed_row[2].strip():
                fixed_row[2] = 'Active'   # status
            if not fixed_row[3].strip():
                fixed_row[3] = '2023-01-01'  # date
                
            writer.writerow(fixed_row)

print(f'CSV fixed and saved to {output_file}') 