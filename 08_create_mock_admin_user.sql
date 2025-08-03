-- Mock User Data for Testing
-- Run this after setting up the authentication schema

-- Step 1: First, you'll need to create the auth user manually through Supabase Dashboard or Auth API
-- Go to Authentication > Users in Supabase Dashboard and create a user with:
-- Email: admin@vantracker.com
-- Password: AdminPass123!
-- This will create an entry in auth.users with a UUID

-- Step 2: After creating the auth user, get the UUID and run the following SQL
-- Replace 'YOUR_AUTH_USER_UUID_HERE' with the actual UUID from auth.users

-- Insert mock admin user into public.users table
INSERT INTO public.users (
    id,
    email,
    full_name,
    company_name,
    phone_number,
    role_id,
    is_active,
    created_at,
    updated_at
) VALUES (
    'YOUR_AUTH_USER_UUID_HERE', -- Replace with actual UUID from auth.users
    'admin@vantracker.com',
    'Van Tracker Admin',
    'Van Fleet Solutions',
    '+1-555-0123',
    (SELECT id FROM user_roles WHERE role_name = 'admin'),
    true,
    NOW(),
    NOW()
);

-- Insert subscription for admin user
INSERT INTO public.user_subscriptions (
    user_id,
    plan_id,
    status,
    billing_cycle,
    current_period_start,
    current_period_end,
    created_at,
    updated_at
) VALUES (
    'YOUR_AUTH_USER_UUID_HERE', -- Replace with actual UUID from auth.users
    (SELECT id FROM subscription_plans WHERE plan_name = 'Enterprise'),
    'active',
    'monthly',
    NOW(),
    NOW() + INTERVAL '1 month',
    NOW(),
    NOW()
);

-- Insert some initial payment history
INSERT INTO public.payment_history (
    user_id,
    subscription_id,
    amount,
    currency,
    payment_method,
    transaction_id,
    status,
    payment_date,
    created_at
) VALUES (
    'YOUR_AUTH_USER_UUID_HERE', -- Replace with actual UUID from auth.users
    (SELECT id FROM user_subscriptions WHERE user_id = 'YOUR_AUTH_USER_UUID_HERE'),
    99.99,
    'USD',
    'credit_card',
    'txn_' || generate_random_uuid(),
    'completed',
    NOW() - INTERVAL '1 day',
    NOW()
);

-- Initialize usage statistics for admin user
INSERT INTO public.usage_statistics (
    user_id,
    photos_uploaded_today,
    photos_uploaded_this_week,
    photos_uploaded_this_month,
    photos_uploaded_this_year,
    total_vans_count,
    active_vans_count,
    maintenance_vans_count,
    out_of_service_vans_count,
    total_damage_reports,
    new_damage_reports_today,
    new_damage_reports_this_week,
    new_damage_reports_this_month,
    storage_used_mb,
    last_updated
) VALUES (
    'YOUR_AUTH_USER_UUID_HERE', -- Replace with actual UUID from auth.users
    5,
    24,
    89,
    445,
    12,
    10,
    1,
    1,
    23,
    2,
    8,
    23,
    156.7,
    NOW()
);

-- Alternative: Create complete mock user with known UUID for easier testing
-- This approach uses a fixed UUID that you can use in your tests

-- Create test admin user with fixed UUID (easier for testing)
DO $$
DECLARE
    test_admin_id UUID := '11111111-1111-1111-1111-111111111111';
BEGIN
    -- Insert into users table
    INSERT INTO public.users (
        id,
        email,
        full_name,
        company_name,
        phone_number,
        role_id,
        is_active,
        created_at,
        updated_at
    ) VALUES (
        test_admin_id,
        'testadmin@vantracker.com',
        'Test Admin User',
        'Test Van Company',
        '+1-555-9999',
        (SELECT id FROM user_roles WHERE role_name = 'admin'),
        true,
        NOW(),
        NOW()
    ) ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        full_name = EXCLUDED.full_name,
        company_name = EXCLUDED.company_name,
        phone_number = EXCLUDED.phone_number,
        role_id = EXCLUDED.role_id,
        updated_at = NOW();

    -- Insert subscription
    INSERT INTO public.user_subscriptions (
        user_id,
        plan_id,
        status,
        billing_cycle,
        current_period_start,
        current_period_end,
        created_at,
        updated_at
    ) VALUES (
        test_admin_id,
        (SELECT id FROM subscription_plans WHERE plan_name = 'Enterprise'),
        'active',
        'monthly',
        NOW(),
        NOW() + INTERVAL '1 month',
        NOW(),
        NOW()
    ) ON CONFLICT (user_id, plan_id) DO UPDATE SET
        status = EXCLUDED.status,
        current_period_end = EXCLUDED.current_period_end,
        updated_at = NOW();

    -- Insert usage statistics
    INSERT INTO public.usage_statistics (
        user_id,
        photos_uploaded_today,
        photos_uploaded_this_week,
        photos_uploaded_this_month,
        photos_uploaded_this_year,
        total_vans_count,
        active_vans_count,
        maintenance_vans_count,
        out_of_service_vans_count,
        total_damage_reports,
        new_damage_reports_today,
        new_damage_reports_this_week,
        new_damage_reports_this_month,
        storage_used_mb,
        last_updated
    ) VALUES (
        test_admin_id,
        8,
        32,
        124,
        567,
        15,
        12,
        2,
        1,
        34,
        3,
        12,
        34,
        234.5,
        NOW()
    ) ON CONFLICT (user_id) DO UPDATE SET
        photos_uploaded_today = EXCLUDED.photos_uploaded_today,
        photos_uploaded_this_week = EXCLUDED.photos_uploaded_this_week,
        photos_uploaded_this_month = EXCLUDED.photos_uploaded_this_month,
        photos_uploaded_this_year = EXCLUDED.photos_uploaded_this_year,
        total_vans_count = EXCLUDED.total_vans_count,
        active_vans_count = EXCLUDED.active_vans_count,
        maintenance_vans_count = EXCLUDED.maintenance_vans_count,
        out_of_service_vans_count = EXCLUDED.out_of_service_vans_count,
        total_damage_reports = EXCLUDED.total_damage_reports,
        new_damage_reports_today = EXCLUDED.new_damage_reports_today,
        new_damage_reports_this_week = EXCLUDED.new_damage_reports_this_week,
        new_damage_reports_this_month = EXCLUDED.new_damage_reports_this_month,
        storage_used_mb = EXCLUDED.storage_used_mb,
        last_updated = NOW();

END $$;

-- Create test crew user
DO $$
DECLARE
    test_crew_id UUID := '22222222-2222-2222-2222-222222222222';
BEGIN
    INSERT INTO public.users (
        id,
        email,
        full_name,
        company_name,
        phone_number,
        role_id,
        is_active,
        created_at,
        updated_at
    ) VALUES (
        test_crew_id,
        'testcrew@vantracker.com',
        'Test Crew Member',
        'Test Van Company',
        '+1-555-8888',
        (SELECT id FROM user_roles WHERE role_name = 'crew'),
        true,
        NOW(),
        NOW()
    ) ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        full_name = EXCLUDED.full_name,
        company_name = EXCLUDED.company_name,
        phone_number = EXCLUDED.phone_number,
        role_id = EXCLUDED.role_id,
        updated_at = NOW();

    INSERT INTO public.user_subscriptions (
        user_id,
        plan_id,
        status,
        billing_cycle,
        current_period_start,
        current_period_end,
        created_at,
        updated_at
    ) VALUES (
        test_crew_id,
        (SELECT id FROM subscription_plans WHERE plan_name = 'Professional'),
        'active',
        'yearly',
        NOW(),
        NOW() + INTERVAL '1 year',
        NOW(),
        NOW()
    ) ON CONFLICT (user_id, plan_id) DO UPDATE SET
        status = EXCLUDED.status,
        current_period_end = EXCLUDED.current_period_end,
        updated_at = NOW();
END $$;

-- Create test viewer user
DO $$
DECLARE
    test_viewer_id UUID := '33333333-3333-3333-3333-333333333333';
BEGIN
    INSERT INTO public.users (
        id,
        email,
        full_name,
        company_name,
        phone_number,
        role_id,
        is_active,
        created_at,
        updated_at
    ) VALUES (
        test_viewer_id,
        'testviewer@vantracker.com',
        'Test Viewer User',
        'Test Van Company',
        '+1-555-7777',
        (SELECT id FROM user_roles WHERE role_name = 'viewer'),
        true,
        NOW(),
        NOW()
    ) ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        full_name = EXCLUDED.full_name,
        company_name = EXCLUDED.company_name,
        phone_number = EXCLUDED.phone_number,
        role_id = EXCLUDED.role_id,
        updated_at = NOW();

    INSERT INTO public.user_subscriptions (
        user_id,
        plan_id,
        status,
        billing_cycle,
        current_period_start,
        current_period_end,
        created_at,
        updated_at
    ) VALUES (
        test_viewer_id,
        (SELECT id FROM subscription_plans WHERE plan_name = 'Starter'),
        'active',
        'monthly',
        NOW(),
        NOW() + INTERVAL '1 month',
        NOW(),
        NOW()
    ) ON CONFLICT (user_id, plan_id) DO UPDATE SET
        status = EXCLUDED.status,
        current_period_end = EXCLUDED.current_period_end,
        updated_at = NOW();
END $$; 