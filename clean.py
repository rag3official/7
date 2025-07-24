import csv

with open('/Users/prolix/7/Van Records - Sheet1-3.csv', 'r') as fin, open('best_fixed.csv', 'w', newline='') as fout:
    # Read input file
    reader = csv.reader(fin)
    headers = next(reader)
    
    # Create writer
    writer = csv.writer(fout)
    writer.writerow(headers)  # Write headers
    
    # Process each row
    for row in reader:
        if row and row[0]:  # Only process rows with van_number
            # Ensure we have exactly 10 columns
            while len(row) < 10:
                row.append('')
            
            # Default values for required fields
            if not row[1]:
                row[1] = 'Unknown'  # type
            if not row[2]:
                row[2] = 'Active'   # status
            if not row[3]:
                row[3] = '2023-01-01'  # date
                
            # Write the cleaned row
            writer.writerow(row[:10])

print('CSV cleaned and saved to best_fixed.csv') 