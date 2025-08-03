-- Simple Mock User Setup for Testing
-- This script just inserts data without complex conflict handling

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
        );

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
        );

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
        );

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
    us.status as subscription_status
FROM public.users u
JOIN public.user_roles ur ON u.role_id = ur.id
LEFT JOIN public.user_subscriptions us ON u.id = us.user_id
LEFT JOIN public.subscription_plans sp ON us.plan_id = sp.id
WHERE u.email IN ('testadmin@vantracker.com', 'testcrew@vantracker.com', 'testviewer@vantracker.com')
ORDER BY ur.role_name;

COMMIT; 