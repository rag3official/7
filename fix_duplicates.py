import csv
import re

# File paths
input_file = 'Van Records - Sheet1-3.csv'
output_file = 'unique_vans.csv'

# Read the entire file content to handle line breaks in fields
with open(input_file, 'r') as f:
    content = f.read()
    
# Replace line breaks within content (not between records)
content = re.sub(r'(https://[^\s,]+)\n([^\s,]+)', r'\1 \2', content)
content = re.sub(r'(http://[^\s,]+)\n([^\s,]+)', r'\1 \2', content)
content = re.sub(r'(drive.google.com[^\s,]+)\n([^\s,]+)', r'\1 \2', content)

# Process the content line by line
lines = content.split('\n')
filtered_rows = []
current_row = []

# Process header
header = lines[0].split(',')
filtered_rows.append(header)

# Process data rows
for line in lines[1:]:
    parts = line.split(',')
    # If this is a new row (starts with van_ or slack_)
    if parts and parts[0] and (parts[0].startswith('van_') or parts[0].startswith('slack_') or parts[0].startswith('van ')):
        if current_row:  # Save previous row if exists
            filtered_rows.append(current_row)
        current_row = parts
    else:
        # This might be a continued row, concat with previous
        if current_row and line.strip():
            # If we have a URL that was split
            if len(current_row) >= 7 and current_row[6]:
                current_row[6] += ' ' + line.strip()
            # Otherwise just add as additional fields
            else:
                current_row.extend(parts)

# Add the last row
if current_row:
    filtered_rows.append(current_row)

# Track van numbers we've seen to handle duplicates
seen_van_numbers = {}
unique_rows = []

# Write the cleaned data
with open(output_file, 'w', newline='') as outfile:
    writer = csv.writer(outfile)
    
    # Write header row
    writer.writerow(['van_number', 'type', 'status', 'date', 'last_updated', 
                    'notes', 'url', 'driver', 'damage', 'damage_description'])
    
    # Process each row
    for row in filtered_rows[1:]:  # Skip header
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
            
            # Handle duplicate van numbers
            original_van_number = fixed_row[0]
            if original_van_number in seen_van_numbers:
                # Add a suffix to make it unique
                seen_van_numbers[original_van_number] += 1
                fixed_row[0] = f"{original_van_number}_{seen_van_numbers[original_van_number]}"
            else:
                seen_van_numbers[original_van_number] = 0
                
            writer.writerow(fixed_row)

print(f'CSV fixed with unique van numbers and saved to {output_file}') 