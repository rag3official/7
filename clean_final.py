import csv
import re

input_file = '/Users/prolix/7/unique_vans.csv'
output_file = '/Users/prolix/7/final_import.csv'

# Read the entire file content to handle line breaks within fields
with open(input_file, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix line breaks in URLs
content = re.sub(r'(https://[^\s,]+)\n([^\s,]+)', r'\1\2', content)
content = re.sub(r'(http://[^\s,]+)\n([^\s,]+)', r'\1\2', content)
content = re.sub(r'(drive.google.com[^\s,]+)\n([^\s,]+)', r'\1\2', content)

# Split the content into lines and process them
lines = content.split('\n')
header = lines[0].split(',')
processed_rows = [header]
seen_van_numbers = set()

for line in lines[1:]:
    if not line.strip():
        continue  # Skip empty lines
    
    parts = line.split(',')
    # Ensure we have a valid line with at least one comma (to separate van_number from other fields)
    if len(parts) > 1:
        van_number = parts[0].strip()
        # Skip rows that don't have a van number
        if not van_number:
            continue
            
        # Make van number unique if it's a duplicate
        original_van_number = van_number
        counter = 1
        while van_number in seen_van_numbers:
            van_number = f"{original_van_number}_{counter}"
            counter += 1
        
        seen_van_numbers.add(van_number)
        
        # Ensure we have exactly 10 columns
        row = [van_number]
        
        # Add the rest of the columns, ensuring we have exactly 10
        for i in range(1, 10):
            if i < len(parts):
                row.append(parts[i])
            else:
                # Add default values for missing fields
                if i == 1:  # type
                    row.append("Unknown")
                elif i == 2:  # status
                    row.append("Active")
                elif i == 3:  # date
                    row.append("2023-01-01")
                else:
                    row.append("")
                    
        processed_rows.append(row)

# Write the cleaned data
with open(output_file, 'w', newline='', encoding='utf-8') as f:
    writer = csv.writer(f)
    for row in processed_rows:
        writer.writerow(row)

print(f"CSV cleaned and saved to {output_file}")

# Additionally create a small test file with a few clean records
test_file = '/Users/prolix/7/clean_test_import.csv'
with open(test_file, 'w', newline='', encoding='utf-8') as f:
    writer = csv.writer(f)
    # Write header
    writer.writerow(header)
    # Write a few test records
    writer.writerow(['test_van_1', 'Van', 'Active', '2023-04-01', '', 'Test notes', 'https://example.com/image.jpg', 'John Doe', 'Minor scratches', 'Few scratches on door'])
    writer.writerow(['test_van_2', 'Car', 'Inactive', '2023-04-02', '', 'More test notes', 'https://example.com/image2.jpg', 'Jane Smith', 'Dent', 'Small dent on bumper'])
    writer.writerow(['test_van_3', 'Truck', 'Active', '2023-04-03', '', '', 'https://example.com/image3.jpg', '', 'Clean', 'No damage'])

print(f"Test file created at {test_file}") 