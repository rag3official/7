-- Authentication and Subscription System Schema - CORRECTED VERSION
-- This extends the existing van damage tracker with user management
-- FIXED: Uses van_profiles instead of vans table
-- Run this after your existing schema setup

BEGIN;

-- =============================================================================
-- 1. USER ROLES TABLE
-- =============================================================================

-- Create roles table (separate for better normalization)
CREATE TABLE IF NOT EXISTS public.user_roles (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    role_name text NOT NULL UNIQUE,
    role_description text,
    permissions jsonb NOT NULL DEFAULT '{}',
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Insert default roles
INSERT INTO public.user_roles (role_name, role_description, permissions) VALUES
('admin', 'Full system access', '{
  "can_add_vans": true,
  "can_remove_vans": true,
  "can_add_drivers": true,
  "can_remove_drivers": true,
  "can_change_van_status": true,
  "can_view_all_statistics": true,
  "can_manage_subscriptions": true,
  "can_manage_users": true
}'),
('crew', 'Maintenance crew access', '{
  "can_add_vans": false,
  "can_remove_vans": false,
  "can_add_drivers": false,
  "can_remove_drivers": false,
  "can_change_van_status": true,
  "can_add_maintenance_notes": true,
  "can_view_basic_statistics": true,
  "can_manage_subscriptions": false,
  "can_manage_users": false
}'),
('viewer', 'Read-only access', '{
  "can_add_vans": false,
  "can_remove_vans": false,
  "can_add_drivers": false,
  "can_remove_drivers": false,
  "can_change_van_status": false,
  "can_view_basic_statistics": true,
  "can_manage_subscriptions": false,
  "can_manage_users": false
}')
ON CONFLICT (role_name) DO UPDATE SET
  permissions = EXCLUDED.permissions,
  updated_at = now();

-- =============================================================================
-- 2. SUBSCRIPTION PLANS TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.subscription_plans (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    plan_name text NOT NULL UNIQUE,
    plan_description text,
    price_monthly decimal(10,2) NOT NULL,
    price_yearly decimal(10,2),
    max_vans integer,
    max_users integer,
    max_photos_per_month integer,
    features jsonb DEFAULT '{}',
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Insert default subscription plans
INSERT INTO public.subscription_plans (plan_name, plan_description, price_monthly, price_yearly, max_vans, max_users, max_photos_per_month, features) VALUES
('Starter', 'Perfect for small fleets', 29.99, 299.99, 10, 3, 1000, '{
  "custom_reports": false,
  "api_access": false,
  "priority_support": false,
  "data_export": true
}'),
('Professional', 'Great for growing businesses', 79.99, 799.99, 50, 10, 5000, '{
  "custom_reports": true,
  "api_access": true,
  "priority_support": false,
  "data_export": true,
  "advanced_analytics": true
}'),
('Enterprise', 'For large fleet operations', 199.99, 1999.99, -1, -1, -1, '{
  "custom_reports": true,
  "api_access": true,
  "priority_support": true,
  "data_export": true,
  "advanced_analytics": true,
  "white_label": true,
  "dedicated_support": true
}')
ON CONFLICT (plan_name) DO NOTHING;

-- =============================================================================
-- 3. USERS TABLE (extends existing auth)
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.users (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    auth_user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    email text NOT NULL UNIQUE,
    full_name text NOT NULL,
    company_name text,
    phone text,
    role_id uuid REFERENCES public.user_roles(id) NOT NULL,
    subscription_id uuid,
    is_active boolean DEFAULT true,
    profile_image_url text,
    timezone text DEFAULT 'UTC',
    preferences jsonb DEFAULT '{}',
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    last_login_at timestamptz
);

-- =============================================================================
-- 4. USER SUBSCRIPTIONS TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.user_subscriptions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
    plan_id uuid REFERENCES public.subscription_plans(id) NOT NULL,
    status text DEFAULT 'active' CHECK (status IN ('active', 'canceled', 'expired', 'trial', 'suspended')),
    billing_cycle text DEFAULT 'monthly' CHECK (billing_cycle IN ('monthly', 'yearly')),
    current_period_start timestamptz NOT NULL DEFAULT now(),
    current_period_end timestamptz NOT NULL,
    trial_end timestamptz,
    cancel_at_period_end boolean DEFAULT false,
    stripe_subscription_id text UNIQUE,
    stripe_customer_id text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Add foreign key for subscription_id in users table
ALTER TABLE public.users 
ADD CONSTRAINT fk_users_subscription 
FOREIGN KEY (subscription_id) REFERENCES public.user_subscriptions(id);

-- =============================================================================
-- 5. PAYMENT HISTORY TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.payment_history (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    subscription_id uuid REFERENCES public.user_subscriptions(id) ON DELETE CASCADE,
    user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
    amount decimal(10,2) NOT NULL,
    currency text DEFAULT 'USD',
    status text DEFAULT 'pending' CHECK (status IN ('pending', 'succeeded', 'failed', 'refunded')),
    payment_method text, -- 'card', 'bank_transfer', etc.
    stripe_payment_intent_id text UNIQUE,
    stripe_invoice_id text,
    invoice_url text,
    payment_date timestamptz DEFAULT now(),
    period_start timestamptz NOT NULL,
    period_end timestamptz NOT NULL,
    description text,
    metadata jsonb DEFAULT '{}',
    created_at timestamptz DEFAULT now()
);

-- =============================================================================
-- 6. USAGE STATISTICS TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.usage_statistics (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
    subscription_id uuid REFERENCES public.user_subscriptions(id) ON DELETE CASCADE,
    stat_date date NOT NULL DEFAULT CURRENT_DATE,
    photos_uploaded_today integer DEFAULT 0,
    photos_uploaded_week integer DEFAULT 0,
    photos_uploaded_month integer DEFAULT 0,
    photos_uploaded_year integer DEFAULT 0,
    vans_with_new_damage integer DEFAULT 0,
    total_damage_reports integer DEFAULT 0,
    active_vans_count integer DEFAULT 0,
    maintenance_vans_count integer DEFAULT 0,
    out_of_service_vans_count integer DEFAULT 0,
    total_users_count integer DEFAULT 0,
    api_calls_today integer DEFAULT 0,
    storage_used_gb decimal(10,2) DEFAULT 0,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    UNIQUE(user_id, stat_date)
);

-- =============================================================================
-- 7. MAINTENANCE LOGS TABLE (enhanced) - CORRECTED TO USE van_profiles
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.maintenance_logs (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    van_id uuid REFERENCES public.van_profiles(id) ON DELETE CASCADE,
    performed_by_user_id uuid REFERENCES public.users(id),
    maintenance_type text NOT NULL CHECK (maintenance_type IN ('routine', 'repair', 'inspection', 'emergency')),
    status_change_from text,
    status_change_to text NOT NULL,
    description text NOT NULL,
    work_performed text,
    parts_replaced jsonb DEFAULT '[]',
    cost decimal(10,2),
    labor_hours decimal(4,2),
    next_maintenance_date date,
    priority text DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'critical')),
    attachments jsonb DEFAULT '[]', -- image URLs, documents, etc.
    scheduled_date timestamptz,
    started_at timestamptz,
    completed_at timestamptz,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- =============================================================================
-- 8. AUDIT LOG TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.audit_logs (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES public.users(id),
    action text NOT NULL,
    table_name text NOT NULL,
    record_id uuid,
    old_values jsonb,
    new_values jsonb,
    ip_address inet,
    user_agent text,
    created_at timestamptz DEFAULT now()
);

-- =============================================================================
-- 9. CREATE INDEXES FOR PERFORMANCE
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_users_role_id ON public.users(role_id);
CREATE INDEX IF NOT EXISTS idx_users_auth_user_id ON public.users(auth_user_id);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_id ON public.user_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_status ON public.user_subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_payment_history_user_id ON public.payment_history(user_id);
CREATE INDEX IF NOT EXISTS idx_payment_history_payment_date ON public.payment_history(payment_date);
CREATE INDEX IF NOT EXISTS idx_usage_statistics_user_id_date ON public.usage_statistics(user_id, stat_date);
CREATE INDEX IF NOT EXISTS idx_maintenance_logs_van_id ON public.maintenance_logs(van_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_logs_performed_by ON public.maintenance_logs(performed_by_user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON public.audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at);

-- =============================================================================
-- 10. ENABLE ROW LEVEL SECURITY
-- =============================================================================

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usage_statistics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- 11. CREATE RLS POLICIES
-- =============================================================================

-- User roles - readable by authenticated users, manageable by admins
CREATE POLICY "Users can view roles" ON public.user_roles FOR SELECT USING (auth.role() = 'authenticated');

-- Subscription plans - readable by authenticated users
CREATE POLICY "Users can view subscription plans" ON public.subscription_plans FOR SELECT USING (auth.role() = 'authenticated');

-- Users - users can see their own data, admins can see all
CREATE POLICY "Users can view own profile" ON public.users FOR SELECT USING (auth.uid() = auth_user_id);
CREATE POLICY "Users can update own profile" ON public.users FOR UPDATE USING (auth.uid() = auth_user_id);

-- User subscriptions - users can see their own subscriptions
CREATE POLICY "Users can view own subscriptions" ON public.user_subscriptions FOR ALL USING (
    user_id IN (SELECT id FROM public.users WHERE auth_user_id = auth.uid())
);

-- Payment history - users can see their own payment history
CREATE POLICY "Users can view own payment history" ON public.payment_history FOR SELECT USING (
    user_id IN (SELECT id FROM public.users WHERE auth_user_id = auth.uid())
);

-- Usage statistics - users can see their own statistics
CREATE POLICY "Users can view own statistics" ON public.usage_statistics FOR ALL USING (
    user_id IN (SELECT id FROM public.users WHERE auth_user_id = auth.uid())
);

-- Maintenance logs - crew and admin can manage
CREATE POLICY "Authenticated users can view maintenance logs" ON public.maintenance_logs FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Crew and admin can manage maintenance logs" ON public.maintenance_logs FOR ALL USING (
    EXISTS (
        SELECT 1 FROM public.users u 
        JOIN public.user_roles r ON u.role_id = r.id 
        WHERE u.auth_user_id = auth.uid() 
        AND r.role_name IN ('admin', 'crew')
    )
);

-- Audit logs - admin only
CREATE POLICY "Admin can view audit logs" ON public.audit_logs FOR ALL USING (
    EXISTS (
        SELECT 1 FROM public.users u 
        JOIN public.user_roles r ON u.role_id = r.id 
        WHERE u.auth_user_id = auth.uid() 
        AND r.role_name = 'admin'
    )
);

-- =============================================================================
-- 12. GRANT PERMISSIONS
-- =============================================================================

GRANT ALL ON public.user_roles TO authenticated, service_role;
GRANT ALL ON public.subscription_plans TO authenticated, service_role;
GRANT ALL ON public.users TO authenticated, service_role;
GRANT ALL ON public.user_subscriptions TO authenticated, service_role;
GRANT ALL ON public.payment_history TO authenticated, service_role;
GRANT ALL ON public.usage_statistics TO authenticated, service_role;
GRANT ALL ON public.maintenance_logs TO authenticated, service_role;
GRANT ALL ON public.audit_logs TO authenticated, service_role;

-- =============================================================================
-- 13. CREATE FUNCTIONS FOR STATISTICS UPDATES
-- =============================================================================

-- Function to update daily statistics
CREATE OR REPLACE FUNCTION update_usage_statistics()
RETURNS TRIGGER AS $$
BEGIN
    -- Update statistics when new van images are uploaded
    IF TG_TABLE_NAME = 'van_images' AND TG_OP = 'INSERT' THEN
        INSERT INTO public.usage_statistics (
            user_id, 
            stat_date,
            photos_uploaded_today,
            photos_uploaded_week,
            photos_uploaded_month,
            photos_uploaded_year
        )
        SELECT 
            u.id,
            CURRENT_DATE,
            1,
            1,
            1,
            1
        FROM public.users u
        WHERE u.auth_user_id = auth.uid()
        ON CONFLICT (user_id, stat_date) 
        DO UPDATE SET
            photos_uploaded_today = usage_statistics.photos_uploaded_today + 1,
            photos_uploaded_week = usage_statistics.photos_uploaded_week + 1,
            photos_uploaded_month = usage_statistics.photos_uploaded_month + 1,
            photos_uploaded_year = usage_statistics.photos_uploaded_year + 1,
            updated_at = now();
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for van_images
CREATE TRIGGER trigger_update_photo_statistics
    AFTER INSERT ON public.van_images
    FOR EACH ROW
    EXECUTE FUNCTION update_usage_statistics();

-- =============================================================================
-- 14. CREATE ADMIN USER FUNCTION
-- =============================================================================

-- Function to create the first admin user
CREATE OR REPLACE FUNCTION create_admin_user(
    user_email text,
    user_full_name text,
    user_company text DEFAULT NULL
)
RETURNS uuid AS $$
DECLARE
    admin_role_id uuid;
    new_user_id uuid;
BEGIN
    -- Get admin role ID
    SELECT id INTO admin_role_id FROM public.user_roles WHERE role_name = 'admin';
    
    -- Create user record
    INSERT INTO public.users (
        email,
        full_name,
        company_name,
        role_id,
        is_active
    ) VALUES (
        user_email,
        user_full_name,
        user_company,
        admin_role_id,
        true
    ) RETURNING id INTO new_user_id;
    
    RETURN new_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;

-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================

-- Check all new tables were created
SELECT 
    table_name,
    (SELECT count(*) FROM information_schema.columns WHERE table_name = t.table_name AND table_schema = 'public') as column_count
FROM information_schema.tables t
WHERE table_schema = 'public' 
AND table_name IN (
    'user_roles', 'subscription_plans', 'users', 'user_subscriptions', 
    'payment_history', 'usage_statistics', 'maintenance_logs', 'audit_logs'
)
ORDER BY table_name;

-- Check sample data
SELECT 'Roles created:' as info, count(*) as count FROM public.user_roles
UNION ALL
SELECT 'Plans created:', count(*) FROM public.subscription_plans; 