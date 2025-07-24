import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { supabase, supabaseAdmin } from '../setup';

describe('Storage Security', () => {
  let testUser: any;
  let testAdmin: any;
  let testVan: any;
  let initialAdmin: any;
  let testUserProfile: any;
  
  beforeAll(async () => {
    try {
      // Create initial admin user
      const { data: initialAdminData, error: initialAdminError } = await supabaseAdmin.auth.admin.createUser({
        email: 'initial_admin@gmail.com',
        password: 'initial_admin123!',
        email_confirm: true
      });

      if (initialAdminError) {
        throw new Error(`Failed to create initial admin: ${initialAdminError.message}`);
      }
      if (!initialAdminData?.user) {
        throw new Error('Initial admin creation returned no user data');
      }
      initialAdmin = { user: initialAdminData.user };

      // Add initial admin to admin_users table
      await supabaseAdmin.from('admin_users').insert({
        id: initialAdmin.user.id,
        created_by: initialAdmin.user.id
      }).select();

      // Create test user using admin client
      const { data: userData, error: userError } = await supabaseAdmin.auth.admin.createUser({
        email: 'test_user@gmail.com',
        password: 'test_password123!',
        email_confirm: true
      });

      if (userError) {
        throw new Error(`Failed to create test user: ${userError.message}`);
      }
      if (!userData?.user) {
        throw new Error('Test user creation returned no user data');
      }
      testUser = { user: userData.user };

      // Create driver profile for test user
      const { data: profileData, error: profileError } = await supabaseAdmin
        .from('driver_profiles')
        .insert({
          id: testUser.user.id,
          name: 'Test User',
          license_number: 'TEST123',
          license_expiry: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
          phone_number: '555-0123',
          email: 'test_user@gmail.com',
          status: 'active',
          certifications: [],
          additional_info: { test: true }
        })
        .select()
        .single();

      if (profileError) {
        throw new Error(`Failed to create driver profile: ${profileError.message}`);
      }
      testUserProfile = profileData;

      // Create test admin using admin client
      const { data: adminData, error: adminError } = await supabaseAdmin.auth.admin.createUser({
        email: 'test_admin@gmail.com',
        password: 'admin_password123!',
        email_confirm: true
      });

      if (adminError) {
        throw new Error(`Failed to create test admin: ${adminError.message}`);
      }
      if (!adminData?.user) {
        throw new Error('Test admin creation returned no user data');
      }
      testAdmin = { user: adminData.user };

      // Sign in as initial admin
      const { error: signInError } = await supabase.auth.signInWithPassword({
        email: 'initial_admin@gmail.com',
        password: 'initial_admin123!'
      });

      if (signInError) {
        throw new Error(`Failed to sign in as initial admin: ${signInError.message}`);
      }

      // Promote test admin using SQL function
      const { error: promoteError } = await supabase.rpc('promote_to_admin', { 
        user_id: testAdmin.user.id 
      });

      if (promoteError) {
        throw new Error(`Failed to promote admin: ${promoteError.message}`);
      }

      // Create test van
      const { data: vanData, error: vanError } = await supabaseAdmin
        .from('vans')
        .insert({ van_number: '999', type: 'test', status: 'active' })
        .select()
        .single();

      if (vanError) {
        throw new Error(`Failed to create test van: ${vanError.message}`);
      }
      if (!vanData) {
        throw new Error('Test van creation returned no data');
      }
      testVan = vanData;

      // Assign van to test user
      const { error: assignError } = await supabaseAdmin
        .from('driver_van_assignments')
        .insert({
          driver_id: testUserProfile.id,
          van_id: testVan.id,
          assignment_date: new Date().toISOString().split('T')[0],
          start_time: new Date().toISOString(),
          status: 'active'
        });

      if (assignError) {
        throw new Error(`Failed to assign van: ${assignError.message}`);
      }
    } catch (error) {
      console.error('Setup failed:', error);
      throw error;
    }
  });

  afterAll(async () => {
    try {
      // Only attempt cleanup if the resources were created
      if (testUser?.user?.id) {
        await supabaseAdmin.from('driver_van_assignments').delete().match({ driver_id: testUser.user.id });
        await supabaseAdmin.from('driver_profiles').delete().match({ id: testUser.user.id });
        await supabaseAdmin.auth.admin.deleteUser(testUser.user.id);
      }
      if (testVan?.id) {
        await supabaseAdmin.from('vans').delete().match({ id: testVan.id });
      }
      if (testAdmin?.user?.id) {
        await supabaseAdmin.rpc('demote_from_admin', { user_id: testAdmin.user.id });
        await supabaseAdmin.auth.admin.deleteUser(testAdmin.user.id);
      }
      if (initialAdmin?.user?.id) {
        await supabaseAdmin.from('admin_users').delete().match({ id: initialAdmin.user.id });
        await supabaseAdmin.auth.admin.deleteUser(initialAdmin.user.id);
      }
    } catch (error) {
      console.error('Cleanup failed:', error);
      // Don't throw here as it might mask test failures
    }
  });

  describe('File Upload Validation', () => {
    it('should allow valid JPEG upload', async () => {
      // Sign in as test user
      const { error: signInError } = await supabase.auth.signInWithPassword({
        email: 'test_user@gmail.com',
        password: 'test_password123!'
      });

      expect(signInError).toBeNull();

      const file = new File(['test'], 'test.jpg', { type: 'image/jpeg' });
      const { data, error } = await supabase.storage
        .from('van_images')
        .upload(`van_999/test.jpg`, file);
      
      expect(error).toBeNull();
      expect(data).toBeDefined();
    });

    it('should reject invalid file type', async () => {
      const file = new File(['test'], 'test.pdf', { type: 'application/pdf' });
      const { data, error } = await supabase.storage
        .from('van_images')
        .upload(`van_999/test.pdf`, file);
      
      expect(error).toBeDefined();
      expect(data).toBeNull();
    });

    it('should reject files over size limit', async () => {
      const largeFile = new File([new ArrayBuffer(11 * 1024 * 1024)], 'large.jpg', { type: 'image/jpeg' });
      const { data, error } = await supabase.storage
        .from('van_images')
        .upload(`van_999/large.jpg`, largeFile);
      
      expect(error).toBeDefined();
      expect(data).toBeNull();
    });
  });

  describe('Rate Limiting', () => {
    it('should enforce upload rate limit', async () => {
      const file = new File(['test'], 'test.jpg', { type: 'image/jpeg' });
      const uploads = Array(11).fill(null).map((_, i) => 
        supabase.storage
          .from('van_images')
          .upload(`van_999/test${i}.jpg`, file)
      );

      const results = await Promise.all(uploads);
      const errors = results.filter(r => r.error);
      
      expect(errors.length).toBeGreaterThan(0);
    });

    it('should reset rate limit after window', async () => {
      // Wait for rate limit window to expire
      await new Promise(resolve => setTimeout(resolve, 61000));

      const file = new File(['test'], 'test.jpg', { type: 'image/jpeg' });
      const { data, error } = await supabase.storage
        .from('van_images')
        .upload(`van_999/test_after_wait.jpg`, file);
      
      expect(error).toBeNull();
      expect(data).toBeDefined();
    });
  });

  describe('Access Control', () => {
    it('should allow upload to assigned van', async () => {
      const file = new File(['test'], 'test.jpg', { type: 'image/jpeg' });
      const { data, error } = await supabase.storage
        .from('van_images')
        .upload(`van_999/test_assigned.jpg`, file);
      
      expect(error).toBeNull();
      expect(data).toBeDefined();
    });

    it('should reject upload to unassigned van', async () => {
      const file = new File(['test'], 'test.jpg', { type: 'image/jpeg' });
      const { data, error } = await supabase.storage
        .from('van_images')
        .upload(`van_888/test_unassigned.jpg`, file);
      
      expect(error).toBeDefined();
      expect(data).toBeNull();
    });

    it('should allow admin to upload to any van', async () => {
      // Switch to admin user
      const { error: signInError } = await supabase.auth.signInWithPassword({
        email: 'test_admin@gmail.com',
        password: 'admin_password123!'
      });

      expect(signInError).toBeNull();

      const file = new File(['test'], 'test.jpg', { type: 'image/jpeg' });
      const { data, error } = await supabase.storage
        .from('van_images')
        .upload(`van_888/test_admin.jpg`, file);
      
      expect(error).toBeNull();
      expect(data).toBeDefined();
    });
  });

  describe('Path Validation', () => {
    it('should reject invalid van number format', async () => {
      const file = new File(['test'], 'test.jpg', { type: 'image/jpeg' });
      const { data, error } = await supabase.storage
        .from('van_images')
        .upload(`invalid_van/test.jpg`, file);
      
      expect(error).toBeDefined();
      expect(data).toBeNull();
    });

    it('should reject nested paths', async () => {
      const file = new File(['test'], 'test.jpg', { type: 'image/jpeg' });
      const { data, error } = await supabase.storage
        .from('van_images')
        .upload(`van_999/nested/test.jpg`, file);
      
      expect(error).toBeDefined();
      expect(data).toBeNull();
    });
  });
}); 