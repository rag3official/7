-- Drop existing table if it exists
DROP TABLE IF EXISTS messages;

-- Create messages table
CREATE TABLE messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    message_id TEXT UNIQUE NOT NULL,
    channel_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    message_text TEXT,
    timestamp TEXT NOT NULL,
    image_urls JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    thread_ts TEXT,
    parent_message_id TEXT,
    image_urls_expiry TIMESTAMP WITH TIME ZONE
);

-- Create indexes for better performance
CREATE INDEX idx_messages_channel_id ON messages(channel_id);
CREATE INDEX idx_messages_user_id ON messages(user_id);
CREATE INDEX idx_messages_created_at ON messages(created_at);
CREATE INDEX idx_messages_thread_ts ON messages(thread_ts);

-- Enable Row Level Security
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Create policy to allow all operations (you can restrict this later)
CREATE POLICY "Allow all operations" ON messages
    FOR ALL
    USING (true)
    WITH CHECK (true); 