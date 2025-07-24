import csv
import re

# Input and output file paths
input_file = '/Users/prolix/7/final_import.csv'
output_file = '/Users/prolix/7/supabase_ready.csv'
test_input = '/Users/prolix/7/clean_test_import.csv'
test_output = '/Users/prolix/7/supabase_test.csv'

def fix_csv(in_file, out_file):
    # Read the entire file content to handle line breaks within fields
    with open(in_file, 'r', encoding='utf-8') as file:
        content = file.read()
    
    # Fix line breaks in URLs and other fields
    content = re.sub(r'(https?://[^\s,]+)\n([^\s,]+)', r'\1\2', content)
    content = re.sub(r'(drive\.google\.com[^\s,]+)\n([^\s,]+)', r'\1\2', content)
    
    # Fix any other line breaks in fields (assuming they're not intended)
    lines = content.split('\n')
    fixed_lines = []
    current_line = ""
    
    for line in lines:
        # If the line has fewer than 9 commas, it's likely incomplete
        if current_line and line.count(',') < 9:
            current_line += " " + line
        else:
            if current_line:
                fixed_lines.append(current_line)
            current_line = line
    
    if current_line:
        fixed_lines.append(current_line)
    
    # Convert back to a string
    fixed_content = '\n'.join(fixed_lines)
    
    # Process the content as CSV
    reader = csv.reader(fixed_content.splitlines())
    with open(out_file, 'w', newline='', encoding='utf-8') as outfile:
        writer = csv.writer(outfile)
        for row in reader:
            writer.writerow(row)
    
    print(f"Fixed CSV file saved to {out_file}")

# Fix both files
fix_csv(input_file, output_file)
fix_csv(test_input, test_output)

print("Both files have been processed and are ready for Supabase import!") 