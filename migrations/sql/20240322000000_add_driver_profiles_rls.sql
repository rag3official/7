-- Enable Row Level Security
ALTER TABLE public.driver_profiles ENABLE ROW LEVEL SECURITY;

-- Create policies for driver_profiles table
CREATE POLICY "Enable read access for all users" ON public.driver_profiles
  FOR SELECT USING (true);

CREATE POLICY "Enable insert access for authenticated users" ON public.driver_profiles
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Enable update access for authenticated users" ON public.driver_profiles
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Enable delete access for authenticated users" ON public.driver_profiles
  FOR DELETE USING (auth.role() = 'authenticated');

-- Add comment
COMMENT ON TABLE public.driver_profiles IS 'Stores driver information with RLS policies'; 