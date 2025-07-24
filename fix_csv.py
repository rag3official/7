import csv
import os

input_file = "/Users/prolix/7/Van Records - Sheet1-3.csv"
output_file = "ultimate_fixed_vans.csv"

with open(input_file, 'r') as infile, open(output_file, 'w', newline='') as outfile:
    reader = csv.reader(infile)
    writer = csv.writer(outfile)
    
    # Write header row
    header = next(reader)
    writer.writerow(header)
    
    # Process data rows
    for row in reader:
        # Skip empty rows or rows without van number
        if not row or not row[0]:
            continue
            
        # Ensure we have exactly 10 fields
        fixed_row = row[:10] if len(row) >= 10 else row + [''] * (10 - len(row))
            
        # Set default values for required fields
        if not fixed_row[1]:  # type
            fixed_row[1] = "Unknown"
        if not fixed_row[2]:  # status
            fixed_row[2] = "Active"
        if not fixed_row[3]:  # date
            fixed_row[3] = "2023-01-01"
            
        writer.writerow(fixed_row)

print(f"Fixed CSV file created at {os.path.abspath(output_file)}") 