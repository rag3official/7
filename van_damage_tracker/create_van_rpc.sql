-- Create the RPC function to insert a new van
CREATE OR REPLACE FUNCTION public.create_van(van_data JSONB)
RETURNS SETOF vans
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    INSERT INTO public.vans (
        van_number,
        type,
        status,
        date,
        last_updated,
        notes,
        url,
        driver,
        damage,
        rating
    ) VALUES (
        van_data->>'van_number',
        van_data->>'type',
        van_data->>'status',
        van_data->>'date',
        van_data->>'last_updated',
        van_data->>'notes',
        van_data->>'url',
        van_data->>'driver',
        van_data->>'damage',
        (van_data->>'rating')::numeric
    )
    RETURNING *;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.create_van(JSONB) TO authenticated; 