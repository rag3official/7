import { config } from 'dotenv';

// Load environment variables from .env file
config();

// Increase timeout for rate limit tests
const TIMEOUT = 70000;
if (globalThis.it) {
  globalThis.it.setTimeout(TIMEOUT);
}
if (globalThis.test) {
  globalThis.test.setTimeout(TIMEOUT);
} 