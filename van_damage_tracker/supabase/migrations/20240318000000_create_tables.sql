-- Create vans table
CREATE OR REPLACE FUNCTION create_vans_table()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  CREATE TABLE IF NOT EXISTS vans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    van_number TEXT NOT NULL,
    type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'Active',
    driver TEXT,
    damage TEXT,
    rating DOUBLE PRECISION DEFAULT 0.0,
    image_urls TEXT[] DEFAULT ARRAY[]::TEXT[],
    notes TEXT,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    url TEXT
  );

  -- Create index on van_number for faster lookups
  CREATE INDEX IF NOT EXISTS idx_vans_van_number ON vans(van_number);
END;
$$;

-- Create maintenance records table
CREATE OR REPLACE FUNCTION create_maintenance_records_table()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  CREATE TABLE IF NOT EXISTS maintenance_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    van_id UUID NOT NULL REFERENCES vans(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    date TEXT NOT NULL,
    type TEXT NOT NULL,
    technician TEXT,
    cost DOUBLE PRECISION DEFAULT 0.0,
    mileage INTEGER DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
  );

  -- Create index on van_id for faster lookups
  CREATE INDEX IF NOT EXISTS idx_maintenance_records_van_id ON maintenance_records(van_id);
END;
$$;

-- Enable Row Level Security (RLS)
ALTER TABLE vans ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_records ENABLE ROW LEVEL SECURITY;

-- Create policies for vans table
CREATE POLICY "Enable read access for all users" ON vans
  FOR SELECT USING (true);

CREATE POLICY "Enable insert access for authenticated users" ON vans
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Enable update access for authenticated users" ON vans
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Enable delete access for authenticated users" ON vans
  FOR DELETE USING (auth.role() = 'authenticated');

-- Create policies for maintenance_records table
CREATE POLICY "Enable read access for all users" ON maintenance_records
  FOR SELECT USING (true);

CREATE POLICY "Enable insert access for authenticated users" ON maintenance_records
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Enable update access for authenticated users" ON maintenance_records
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Enable delete access for authenticated users" ON maintenance_records
  FOR DELETE USING (auth.role() = 'authenticated');

-- Create trigger to update last_updated timestamp on vans
CREATE OR REPLACE FUNCTION update_van_last_updated()
RETURNS TRIGGER AS $$
BEGIN
  NEW.last_updated = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_van_last_updated_trigger
  BEFORE UPDATE ON vans
  FOR EACH ROW
  EXECUTE FUNCTION update_van_last_updated();

-- Create trigger to update van last_updated when maintenance record is modified
CREATE OR REPLACE FUNCTION update_van_last_updated_on_maintenance()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE vans
  SET last_updated = CURRENT_TIMESTAMP
  WHERE id = NEW.van_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_van_last_updated_on_maintenance_trigger
  AFTER INSERT OR UPDATE ON maintenance_records
  FOR EACH ROW
  EXECUTE FUNCTION update_van_last_updated_on_maintenance(); 