import { config } from 'dotenv';
import { resolve } from 'path';
import { createClient } from '@supabase/supabase-js';

// Load environment variables from .env file
const result = config({ path: resolve(__dirname, '..', '.env') });

if (result.error) {
  throw new Error(`Error loading .env file: ${result.error.message}`);
}

// Verify environment variables are loaded
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY || process.env.SUPABASE_ANON_KEY; // Check both key names
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_KEY; // Use service role key if available

console.log('Environment variables loaded:', {
  url: supabaseUrl ? '✓' : '✗',
  anonKey: supabaseKey ? '✓' : '✗',
  serviceKey: serviceKey ? '✓' : '✗'
});

if (!supabaseUrl || !supabaseKey || !serviceKey) {
  const missing: string[] = [];
  if (!supabaseUrl) missing.push('SUPABASE_URL');
  if (!supabaseKey) missing.push('SUPABASE_KEY or SUPABASE_ANON_KEY');
  if (!serviceKey) missing.push('SUPABASE_SERVICE_ROLE_KEY');
  throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
}

// Create and export Supabase clients
const supabase = createClient(supabaseUrl, supabaseKey);
const supabaseAdmin = createClient(supabaseUrl, serviceKey);

export { supabase, supabaseAdmin };

// Set timeout for rate limit tests
// Vitest automatically picks up the testTimeout from vitest.config.ts
// No need to set it here anymore 