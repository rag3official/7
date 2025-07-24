# Van Data Processor Lambda Function

This AWS Lambda function processes Slack messages and updates van profiles in a Supabase database. It extracts van numbers from messages and associates any attached images with the correct van profile.

## Schema

The function uses the following Supabase table schema:

```sql
create table public.vans (
  id uuid not null default gen_random_uuid(),
  van_number text not null,
  type text null default 'Unknown'::text,
  status text null default 'Active'::text,
  date text null,
  last_updated text null,
  notes text null default ''::text,
  url text null default ''::text,
  driver text null default ''::text,
  damage text null default ''::text,
  rating numeric null default 0,
  created_at timestamp with time zone null default now(),
  damage_description text null default ''::text,
  constraint vans_pkey primary key (id),
  constraint vans_van_number_key unique (van_number)
)
```

## Setup

1. Create a new Lambda function in AWS
2. Set the runtime to Python 3.9 or later
3. Set the following environment variables:
   - `SUPABASE_URL`: Your Supabase project URL
   - `SUPABASE_KEY`: Your Supabase service role key (or anon key with proper RLS policies)

4. Create a Supabase storage bucket:
   - Name: "van-images"
   - Type: Public (or Private if you want to use signed URLs)
   - Path structure: "van_{number}/slack_image_{timestamp}_{index}.jpg"

## Deployment

1. Install dependencies:
   ```bash
   pip install -r requirements.txt -t .
   ```

2. Create a ZIP file containing:
   - van_processor.py
   - All installed dependencies
   
3. Upload the ZIP file to AWS Lambda

## Usage

The function accepts POST requests with Slack message data in the following format:

```json
{
  "message_text": "Van 71 needs maintenance. Front bumper damaged.",
  "images": [
    "base64_encoded_image_data_1",
    "base64_encoded_image_data_2"
  ]
}
```

### Message Processing

The function:
1. Extracts the van number from the message text (e.g., "van 71" → "71")
2. Creates a new van profile if it doesn't exist
3. Uploads any attached images to Supabase storage in the van's folder
4. Updates the van's profile with:
   - Image URLs
   - Message text (added to notes with timestamp)
   - Last updated timestamp

### Image Organization

Images are stored in Supabase with the following structure:
- Each van has its own folder: `van_{number}/`
- Images are named with timestamps: `slack_image_{timestamp}_{index}.jpg`
- URLs are stored in the van's profile, either:
  - As the first image URL if no previous images
  - Appended to existing image URLs if the van already has images

## Response

Successful response:
```json
{
  "statusCode": 200,
  "body": {
    "message": "Successfully updated van profile",
    "van_id": "uuid-of-van",
    "van_number": "71",
    "image_urls": [
      "https://your-bucket.supabase.co/storage/v1/object/van_71/slack_image_..."
    ]
  }
}
```

Error response:
```json
{
  "statusCode": 500,
  "body": {
    "message": "Error message details"
  }
}
```

## Error Handling

The function includes comprehensive error handling for:
- No van number in message
- Invalid message format
- Image upload failures
- Database connection issues
- Storage bucket access issues
- Duplicate van numbers 