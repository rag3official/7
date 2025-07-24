#!/usr/bin/env python3
import csv
from collections import Counter

INPUT_FILE = '/Users/prolix/7/supabase_ready.csv'
OUTPUT_FILE = '/Users/prolix/7/supabase_deduplicated.csv'

def main():
    # Read the CSV file
    with open(INPUT_FILE, 'r', encoding='utf-8') as file:
        reader = csv.reader(file)
        header = next(reader)
        rows = list(reader)
    
    # Count occurrences of each van number
    van_numbers = [row[0] for row in rows]
    duplicates = [van_num for van_num, count in Counter(van_numbers).items() if count > 1]
    
    if duplicates:
        print(f"Found {len(duplicates)} duplicate van numbers:")
        for van_num in duplicates:
            instances = [i for i, row in enumerate(rows) if row[0] == van_num]
            print(f"Van {van_num} appears {len(instances)} times at rows: {[i+2 for i in instances]}")
            
            # Make duplicates unique by adding suffix
            for idx, row_idx in enumerate(instances[1:], 1):
                rows[row_idx][0] = f"{rows[row_idx][0]}_{idx}"
                print(f"  - Changed to: {rows[row_idx][0]}")
    else:
        print("No duplicates found.")
    
    # Write the deduplicated data
    with open(OUTPUT_FILE, 'w', newline='', encoding='utf-8') as file:
        writer = csv.writer(file)
        writer.writerow(header)
        writer.writerows(rows)
    
    print(f"Saved deduplicated CSV to {OUTPUT_FILE}")

if __name__ == "__main__":
    main() 