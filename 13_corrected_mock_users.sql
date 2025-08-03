-- Corrected Mock User Setup for Testing
-- This script uses the correct column names from the actual tables

-- STEP 1: Create auth users through Supabase Dashboard first
-- Go to Authentication > Users in Supabase Dashboard and create these users:
-- 1. Email: testadmin@vantracker.com, Password: AdminPass123!
-- 2. Email: testcrew@vantracker.com, Password: CrewPass123!  
-- 3. Email: testviewer@vantracker.com, Password: ViewerPass123!

-- STEP 2: Run this script to create their profiles

BEGIN;

-- Clean up any existing test data first
DELETE FROM public.usage_statistics WHERE user_id IN (
    SELECT id FROM public.users WHERE email IN ('testadmin@vantracker.com', 'testcrew@vantracker.com', 'testviewer@vantracker.com')
);

DELETE FROM public.user_subscriptions WHERE user_id IN (
    SELECT id FROM public.users WHERE email IN ('testadmin@vantracker.com', 'testcrew@vantracker.com', 'testviewer@vantracker.com')
);

DELETE FROM public.users WHERE email IN ('testadmin@vantracker.com', 'testcrew@vantracker.com', 'testviewer@vantracker.com');

-- Create admin user profile
DO $$
DECLARE
    admin_auth_id UUID;
    admin_user_id UUID;
    admin_plan_id UUID;
    admin_subscription_id UUID;
BEGIN
    -- Get the UUID from auth.users for the admin email
    SELECT id INTO admin_auth_id FROM auth.users WHERE email = 'testadmin@vantracker.com';
    
    IF admin_auth_id IS NOT NULL THEN
        -- Insert into public.users
        INSERT INTO public.users (
            auth_user_id,
            email,
            full_name,
            company_name,
            phone,
            role_id,
            is_active,
            created_at,
            updated_at
        ) VALUES (
            admin_auth_id,
            'testadmin@vantracker.com',
            'Test Admin User',
            'Van Fleet Solutions',
            '+1-555-0001',
            (SELECT id FROM user_roles WHERE role_name = 'admin'),
            true,
            NOW(),
            NOW()
        ) RETURNING id INTO admin_user_id;

        -- Get plan ID
        SELECT id INTO admin_plan_id FROM subscription_plans WHERE plan_name = 'Enterprise';

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
            admin_plan_id,
            'active',
            'monthly',
            NOW(),
            NOW() + INTERVAL '1 month',
            NOW(),
            NOW()
        ) RETURNING id INTO admin_subscription_id;

        -- Insert usage statistics (using correct column names)
        INSERT INTO public.usage_statistics (
            user_id,
            subscription_id,
            stat_date,
            photos_uploaded_today,
            photos_uploaded_week,
            photos_uploaded_month,
            photos_uploaded_year,
            vans_with_new_damage,
            total_damage_reports,
            active_vans_count,
            maintenance_vans_count,
            out_of_service_vans_count,
            total_users_count,
            api_calls_today,
            storage_used_gb,
            created_at,
            updated_at
        ) VALUES (
            admin_user_id,
            admin_subscription_id,
            CURRENT_DATE,
            12,
            45,
            178,
            892,
            5,
            67,
            20,
            3,
            2,
            25,
            156,
            0.457, -- 456.8 MB = 0.457 GB
            NOW(),
            NOW()
        );

        RAISE NOTICE 'Created admin user: % (profile_id: %)', admin_auth_id, admin_user_id;
    ELSE
        RAISE NOTICE 'Auth user testadmin@vantracker.com not found. Create it first in Supabase Dashboard.';
    END IF;
END $$;

-- Create crew user profile
DO $$
DECLARE
    crew_auth_id UUID;
    crew_user_id UUID;
    crew_plan_id UUID;
    crew_subscription_id UUID;
BEGIN
    SELECT id INTO crew_auth_id FROM auth.users WHERE email = 'testcrew@vantracker.com';
    
    IF crew_auth_id IS NOT NULL THEN
        INSERT INTO public.users (
            auth_user_id,
            email,
            full_name,
            company_name,
            phone,
            role_id,
            is_active,
            created_at,
            updated_at
        ) VALUES (
            crew_auth_id,
            'testcrew@vantracker.com',
            'Test Crew Member',
            'Van Fleet Solutions',
            '+1-555-0002',
            (SELECT id FROM user_roles WHERE role_name = 'crew'),
            true,
            NOW(),
            NOW()
        ) RETURNING id INTO crew_user_id;

        SELECT id INTO crew_plan_id FROM subscription_plans WHERE plan_name = 'Professional';

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
            crew_plan_id,
            'active',
            'yearly',
            NOW(),
            NOW() + INTERVAL '1 year',
            NOW(),
            NOW()
        ) RETURNING id INTO crew_subscription_id;

        INSERT INTO public.usage_statistics (
            user_id,
            subscription_id,
            stat_date,
            photos_uploaded_today,
            photos_uploaded_week,
            photos_uploaded_month,
            photos_uploaded_year,
            vans_with_new_damage,
            total_damage_reports,
            active_vans_count,
            maintenance_vans_count,
            out_of_service_vans_count,
            total_users_count,
            api_calls_today,
            storage_used_gb,
            created_at,
            updated_at
        ) VALUES (
            crew_user_id,
            crew_subscription_id,
            CURRENT_DATE,
            8,
            28,
            95,
            345,
            3,
            34,
            12,
            2,
            1,
            15,
            89,
            0.235, -- 234.5 MB = 0.235 GB
            NOW(),
            NOW()
        );

        RAISE NOTICE 'Created crew user: % (profile_id: %)', crew_auth_id, crew_user_id;
    ELSE
        RAISE NOTICE 'Auth user testcrew@vantracker.com not found.';
    END IF;
END $$;

-- Create viewer user profile
DO $$
DECLARE
    viewer_auth_id UUID;
    viewer_user_id UUID;
    viewer_plan_id UUID;
    viewer_subscription_id UUID;
BEGIN
    SELECT id INTO viewer_auth_id FROM auth.users WHERE email = 'testviewer@vantracker.com';
    
    IF viewer_auth_id IS NOT NULL THEN
        INSERT INTO public.users (
            auth_user_id,
            email,
            full_name,
            company_name,
            phone,
            role_id,
            is_active,
            created_at,
            updated_at
        ) VALUES (
            viewer_auth_id,
            'testviewer@vantracker.com',
            'Test Viewer User',
            'Van Fleet Solutions',
            '+1-555-0003',
            (SELECT id FROM user_roles WHERE role_name = 'viewer'),
            true,
            NOW(),
            NOW()
        ) RETURNING id INTO viewer_user_id;

        SELECT id INTO viewer_plan_id FROM subscription_plans WHERE plan_name = 'Starter';

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
            viewer_plan_id,
            'active',
            'monthly',
            NOW(),
            NOW() + INTERVAL '1 month',
            NOW(),
            NOW()
        ) RETURNING id INTO viewer_subscription_id;

        INSERT INTO public.usage_statistics (
            user_id,
            subscription_id,
            stat_date,
            photos_uploaded_today,
            photos_uploaded_week,
            photos_uploaded_month,
            photos_uploaded_year,
            vans_with_new_damage,
            total_damage_reports,
            active_vans_count,
            maintenance_vans_count,
            out_of_service_vans_count,
            total_users_count,
            api_calls_today,
            storage_used_gb,
            created_at,
            updated_at
        ) VALUES (
            viewer_user_id,
            viewer_subscription_id,
            CURRENT_DATE,
            3,
            12,
            45,
            156,
            1,
            12,
            7,
            1,
            0,
            8,
            23,
            0.089, -- 89.3 MB = 0.089 GB
            NOW(),
            NOW()
        );

        RAISE NOTICE 'Created viewer user: % (profile_id: %)', viewer_auth_id, viewer_user_id;
    ELSE
        RAISE NOTICE 'Auth user testviewer@vantracker.com not found.';
    END IF;
END $$;

-- Show what we created
SELECT 
    u.email,
    u.full_name,
    ur.role_name,
    sp.plan_name,
    us.status as subscription_status,
    stat.photos_uploaded_year,
    stat.storage_used_gb
FROM public.users u
JOIN public.user_roles ur ON u.role_id = ur.id
LEFT JOIN public.user_subscriptions us ON u.id = us.user_id
LEFT JOIN public.subscription_plans sp ON us.plan_id = sp.id
LEFT JOIN public.usage_statistics stat ON u.id = stat.user_id
WHERE u.email IN ('testadmin@vantracker.com', 'testcrew@vantracker.com', 'testviewer@vantracker.com')
ORDER BY ur.role_name;

COMMIT; 