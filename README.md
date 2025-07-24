# van_management_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# Van Management System

## Project Structure

```
.
├── migrations/           # Database migrations
│   └── sql/             # SQL migration files
│       ├── 20240322000009_add_admin_role.sql
│       ├── 20240322000015_update_storage_security.sql
│       └── ...
│
└── security-tests/      # Security test suite
    ├── tests/
    │   ├── setup.ts
    │   └── security/
    │       └── storage_security.test.ts
    ├── package.json
    ├── tsconfig.json
    └── vitest.config.ts
```

## Security Testing

### Setup

1. Install dependencies:
```bash
cd security-tests
npm install
```

2. Configure environment variables:
Create a `.env` file in the security-tests directory:
```
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key # Only needed for admin operations
```

3. Run tests:
```bash
npm test
```

### Security Features

1. **File Upload Security**
   - File type validation (JPEG, PNG, WebP)
   - Size limits (10MB per file)
   - Path validation
   - Rate limiting (10 uploads/minute/user)

2. **Access Control**
   - Van assignment validation
   - Admin role management
   - Row Level Security (RLS)
   - Storage bucket policies

3. **Monitoring**
   - Upload tracking
   - Access logging
   - Rate limit monitoring
   - Security event auditing

### Testing Coverage

The test suite (`security-tests/tests/security/storage_security.test.ts`) covers:
- File upload validation
- Rate limiting
- Access control
- Path validation
- Admin privileges
- Error handling

For detailed test scenarios and implementation, see `docs/security_testing.md`.

## Database Migrations

The SQL migrations in `migrations/sql/` handle:
1. Database schema setup
2. Security policies
3. Access control
4. Rate limiting
5. File validation

To run migrations:
```bash
supabase db reset
# or
supabase migration up
```
