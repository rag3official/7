-- Channel System Database Schema
-- This replaces Slack with a built-in messaging system

-- 1. Driver Channels Table
CREATE TABLE IF NOT EXISTS driver_channels (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    channel_name VARCHAR(100) NOT NULL,
    created_by UUID REFERENCES driver_profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    description TEXT,
    channel_type VARCHAR(20) DEFAULT 'general' -- 'general', 'van_specific', 'admin'
);

-- 2. Channel Messages Table
CREATE TABLE IF NOT EXISTS channel_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    channel_id UUID REFERENCES driver_channels(id) ON DELETE CASCADE,
    driver_id UUID REFERENCES driver_profiles(id) ON DELETE SET NULL,
    message_text TEXT NOT NULL,
    image_url TEXT,
    van_number INTEGER,
    damage_assessment TEXT,
    rating INTEGER CHECK (rating >= 1 AND rating <= 10),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    message_type VARCHAR(20) DEFAULT 'text' -- 'text', 'image', 'damage_report', 'system'
);

-- 3. Driver Channel Memberships
CREATE TABLE IF NOT EXISTS driver_channel_members (
    driver_id UUID REFERENCES driver_profiles(id) ON DELETE CASCADE,
    channel_id UUID REFERENCES driver_channels(id) ON DELETE CASCADE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_admin BOOLEAN DEFAULT false,
    can_send_messages BOOLEAN DEFAULT true,
    PRIMARY KEY (driver_id, channel_id)
);

-- 4. Van Assignments Table (Enhanced)
CREATE TABLE IF NOT EXISTS van_assignments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    driver_id UUID REFERENCES driver_profiles(id) ON DELETE CASCADE,
    van_id UUID REFERENCES van_profiles(id) ON DELETE CASCADE,
    van_number INTEGER NOT NULL,
    van_make VARCHAR(50) DEFAULT 'Unknown',
    van_model VARCHAR(50) DEFAULT 'Unknown',
    van_status VARCHAR(20) DEFAULT 'active',
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    assignment_status VARCHAR(20) DEFAULT 'active' CHECK (assignment_status IN ('active', 'completed', 'cancelled')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Enhanced Van Images Table (with channel integration)
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS channel_message_id UUID REFERENCES channel_messages(id) ON DELETE SET NULL;
ALTER TABLE van_images ADD COLUMN IF NOT EXISTS uploaded_via_channel BOOLEAN DEFAULT false;

-- 6. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_channel_messages_channel_id ON channel_messages(channel_id);
CREATE INDEX IF NOT EXISTS idx_channel_messages_created_at ON channel_messages(created_at);
CREATE INDEX IF NOT EXISTS idx_channel_messages_driver_id ON channel_messages(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_channel_members_driver_id ON driver_channel_members(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_channel_members_channel_id ON driver_channel_members(channel_id);
CREATE INDEX IF NOT EXISTS idx_van_assignments_driver_id ON van_assignments(driver_id);
CREATE INDEX IF NOT EXISTS idx_van_assignments_van_number ON van_assignments(van_number);

-- 7. Row Level Security (RLS) Policies

-- Enable RLS on all tables
ALTER TABLE driver_channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE channel_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_channel_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE van_assignments ENABLE ROW LEVEL SECURITY;

-- Driver Channels RLS
CREATE POLICY "Drivers can view channels they are members of" ON driver_channels
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM driver_channel_members 
            WHERE driver_id = auth.uid()::text::uuid 
            AND channel_id = driver_channels.id
        )
    );

CREATE POLICY "Channel creators can update their channels" ON driver_channels
    FOR UPDATE USING (created_by = auth.uid()::text::uuid);

-- Channel Messages RLS
CREATE POLICY "Drivers can view messages in channels they are members of" ON channel_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM driver_channel_members 
            WHERE driver_id = auth.uid()::text::uuid 
            AND channel_id = channel_messages.channel_id
        )
    );

CREATE POLICY "Drivers can send messages to channels they are members of" ON channel_messages
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM driver_channel_members 
            WHERE driver_id = auth.uid()::text::uuid 
            AND channel_id = channel_messages.channel_id
            AND can_send_messages = true
        )
    );

CREATE POLICY "Drivers can update their own messages" ON channel_messages
    FOR UPDATE USING (driver_id = auth.uid()::text::uuid);

-- Driver Channel Members RLS
CREATE POLICY "Drivers can view their channel memberships" ON driver_channel_members
    FOR SELECT USING (driver_id = auth.uid()::text::uuid);

CREATE POLICY "Drivers can join channels" ON driver_channel_members
    FOR INSERT WITH CHECK (driver_id = auth.uid()::text::uuid);

CREATE POLICY "Drivers can leave channels" ON driver_channel_members
    FOR DELETE USING (driver_id = auth.uid()::text::uuid);

-- Van Assignments RLS
CREATE POLICY "Drivers can view their own assignments" ON van_assignments
    FOR SELECT USING (driver_id = auth.uid()::text::uuid);

CREATE POLICY "Admins can manage all assignments" ON van_assignments
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM driver_profiles 
            WHERE id = auth.uid()::text::uuid 
            AND status = 'admin'
        )
    );

-- 8. Functions for channel operations

-- Function to create a new channel and add creator as member
CREATE OR REPLACE FUNCTION create_driver_channel(
    channel_name_input VARCHAR(100),
    description_input TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    new_channel_id UUID;
    current_driver_id UUID;
BEGIN
    -- Get current driver ID
    SELECT id INTO current_driver_id 
    FROM driver_profiles 
    WHERE slack_user_id = auth.uid()::text;
    
    IF current_driver_id IS NULL THEN
        RAISE EXCEPTION 'Driver profile not found';
    END IF;
    
    -- Create channel
    INSERT INTO driver_channels (channel_name, created_by, description)
    VALUES (channel_name_input, current_driver_id, description_input)
    RETURNING id INTO new_channel_id;
    
    -- Add creator as member
    INSERT INTO driver_channel_members (driver_id, channel_id, is_admin)
    VALUES (current_driver_id, new_channel_id, true);
    
    RETURN new_channel_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get driver's van assignments
CREATE OR REPLACE FUNCTION get_driver_van_assignments(driver_slack_user_id TEXT)
RETURNS TABLE (
    id UUID,
    driver_id UUID,
    van_number INTEGER,
    van_make VARCHAR(50),
    van_model VARCHAR(50),
    van_status VARCHAR(20),
    assigned_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    assignment_status VARCHAR(20)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        va.id,
        va.driver_id,
        va.van_number,
        va.van_make,
        va.van_model,
        va.van_status,
        va.assigned_at,
        va.completed_at,
        va.assignment_status
    FROM van_assignments va
    JOIN driver_profiles dp ON va.driver_id = dp.id
    WHERE dp.slack_user_id = driver_slack_user_id
    AND va.assignment_status = 'active'
    ORDER BY va.assigned_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get channel messages with driver info
CREATE OR REPLACE FUNCTION get_channel_messages(channel_id_input UUID)
RETURNS TABLE (
    id UUID,
    channel_id UUID,
    driver_id UUID,
    message_text TEXT,
    image_url TEXT,
    van_number INTEGER,
    damage_assessment TEXT,
    rating INTEGER,
    created_at TIMESTAMP WITH TIME ZONE,
    driver_name TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cm.id,
        cm.channel_id,
        cm.driver_id,
        cm.message_text,
        cm.image_url,
        cm.van_number,
        cm.damage_assessment,
        cm.rating,
        cm.created_at,
        dp.driver_name
    FROM channel_messages cm
    LEFT JOIN driver_profiles dp ON cm.driver_id = dp.id
    WHERE cm.channel_id = channel_id_input
    ORDER BY cm.created_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. Create default channels
INSERT INTO driver_channels (channel_name, description, channel_type) VALUES
('General', 'General driver communications', 'general'),
('Van Reports', 'Van damage reports and updates', 'van_specific'),
('Admin', 'Administrative communications', 'admin')
ON CONFLICT DO NOTHING;

-- 10. Triggers for automatic updates
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_driver_channels_updated_at 
    BEFORE UPDATE ON driver_channels 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_channel_messages_updated_at 
    BEFORE UPDATE ON channel_messages 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_van_assignments_updated_at 
    BEFORE UPDATE ON van_assignments 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 11. Insert sample data for testing
INSERT INTO driver_channels (channel_name, description) VALUES
('Test Channel', 'Test channel for development')
ON CONFLICT DO NOTHING; 