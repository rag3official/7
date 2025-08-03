-- Easy Mock User Setup for Testing
-- This script works with Supabase's auto-generated UUIDs

-- STEP 1: Create auth users through Supabase Dashboard first
-- Go to Authentication > Users in Supabase Dashboard and create these users:
-- 1. Email: testadmin@vantracker.com, Password: AdminPass123!
-- 2. Email: testcrew@vantracker.com, Password: CrewPass123!  
-- 3. Email: testviewer@vantracker.com, Password: ViewerPass123!

-- STEP 2: Run this script to create their profiles automatically
-- This will find the auth users by email and create corresponding profiles

BEGIN;

-- Create admin user profile
DO $$
DECLARE
    admin_user_id UUID;
BEGIN
    -- Get the UUID from auth.users for the admin email
    SELECT id INTO admin_user_id 
    FROM auth.users 
    WHERE email = 'testadmin@vantracker.com';
    
    -- Only proceed if user exists
    IF admin_user_id IS NOT NULL THEN
        -- Insert into public.users
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
            admin_user_id,
            'testadmin@vantracker.com',
            'Test Admin User',
            'Van Fleet Solutions',
            '+1-555-0001',
            (SELECT id FROM user_roles WHERE role_name = 'admin'),
            true,
            NOW(),
            NOW()
        ) ON CONFLICT (id) DO UPDATE SET
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
            admin_user_id,
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
            admin_user_id,
            12,
            45,
            178,
            892,
            25,
            20,
            3,
            2,
            67,
            5,
            18,
            67,
            456.8,
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

        RAISE NOTICE 'Created admin user profile for: %', admin_user_id;
    ELSE
        RAISE NOTICE 'Auth user with email testadmin@vantracker.com not found. Create it first in Supabase Dashboard.';
    END IF;
END $$;

-- Create crew user profile
DO $$
DECLARE
    crew_user_id UUID;
BEGIN
    SELECT id INTO crew_user_id 
    FROM auth.users 
    WHERE email = 'testcrew@vantracker.com';
    
    IF crew_user_id IS NOT NULL THEN
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
            crew_user_id,
            'testcrew@vantracker.com',
            'Test Crew Member',
            'Van Fleet Solutions',
            '+1-555-0002',
            (SELECT id FROM user_roles WHERE role_name = 'crew'),
            true,
            NOW(),
            NOW()
        ) ON CONFLICT (id) DO UPDATE SET
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
            crew_user_id,
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
            crew_user_id,
            8,
            28,
            95,
            345,
            15,
            12,
            2,
            1,
            34,
            3,
            11,
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

        RAISE NOTICE 'Created crew user profile for: %', crew_user_id;
    ELSE
        RAISE NOTICE 'Auth user with email testcrew@vantracker.com not found. Create it first in Supabase Dashboard.';
    END IF;
END $$;

-- Create viewer user profile
DO $$
DECLARE
    viewer_user_id UUID;
BEGIN
    SELECT id INTO viewer_user_id 
    FROM auth.users 
    WHERE email = 'testviewer@vantracker.com';
    
    IF viewer_user_id IS NOT NULL THEN
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
            viewer_user_id,
            'testviewer@vantracker.com',
            'Test Viewer User',
            'Van Fleet Solutions',
            '+1-555-0003',
            (SELECT id FROM user_roles WHERE role_name = 'viewer'),
            true,
            NOW(),
            NOW()
        ) ON CONFLICT (id) DO UPDATE SET
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
            viewer_user_id,
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
            viewer_user_id,
            3,
            12,
            45,
            156,
            8,
            7,
            1,
            0,
            12,
            1,
            4,
            12,
            89.3,
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

        RAISE NOTICE 'Created viewer user profile for: %', viewer_user_id;
    ELSE
        RAISE NOTICE 'Auth user with email testviewer@vantracker.com not found. Create it first in Supabase Dashboard.';
    END IF;
END $$;

-- Show what we created
SELECT 
    u.email,
    u.full_name,
    ur.role_name,
    sp.plan_name,
    us.status as subscription_status
FROM public.users u
JOIN public.user_roles ur ON u.role_id = ur.id
LEFT JOIN public.user_subscriptions us ON u.id = us.user_id
LEFT JOIN public.subscription_plans sp ON us.plan_id = sp.id
WHERE u.email IN ('testadmin@vantracker.com', 'testcrew@vantracker.com', 'testviewer@vantracker.com')
ORDER BY ur.role_name;

COMMIT; 