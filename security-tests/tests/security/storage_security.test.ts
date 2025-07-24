import { createClient } from '@supabase/supabase-js';
import { describe, it, expect, beforeAll, afterAll } from 'vitest';

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_ANON_KEY!
);

describe('Storage Security', () => {
  let testUser: any;
  let testAdmin: any;
  let testVan: any;
  
  beforeAll(async () => {
    // Create test user
    const { data: user, error: userError } = await supabase.auth.signUp({
      email: 'test_user@example.com',
      password: 'test_password123!'
    });
    testUser = user;

    // Create test admin
    const { data: admin, error: adminError } = await supabase.auth.signUp({
      email: 'test_admin@example.com',
      password: 'admin_password123!'
    });
    testAdmin = admin;

    // Promote to admin using SQL function
    await supabase.rpc('promote_to_admin', { user_id: testAdmin.user.id });

    // Create test van
    const { data: van, error: vanError } = await supabase
      .from('vans')
      .insert({ van_number: '999', type: 'test', status: 'active' })
      .select()
      .single();
    testVan = van;

    // Assign van to test user
    await supabase
      .from('driver_van_assignments')
      .insert({
        driver_id: testUser.user.id,
        van_id: testVan.id,
        assignment_date: new Date()
      });
  });

  afterAll(async () => {
    // Cleanup test data
    await supabase.from('driver_van_assignments').delete().match({ driver_id: testUser.user.id });
    await supabase.from('vans').delete().match({ id: testVan.id });
    await supabase.rpc('demote_from_admin', { user_id: testAdmin.user.id });
    await supabase.auth.admin.deleteUser(testUser.user.id);
    await supabase.auth.admin.deleteUser(testAdmin.user.id);
  });

  describe('File Upload Validation', () => {
    it('should allow valid JPEG upload', async () => {
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
      await supabase.auth.signInWithPassword({
        email: 'test_admin@example.com',
        password: 'admin_password123!'
      });

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