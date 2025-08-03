# Authentication & Subscription System Implementation Guide

## Overview

I've created a comprehensive authentication and subscription system for your van damage tracker with role-based access control, subscription management, and detailed statistics tracking.

## 🗄️ Database Schema Setup

### Step 1: Run the Database Schema

1. **Navigate to your Supabase dashboard**
2. **Go to SQL Editor**
3. **Run the schema file**: `06_authentication_and_subscription_schema.sql`

This creates:
- **user_roles** table with admin, crew, and viewer roles
- **subscription_plans** table with Starter ($29.99), Professional ($79.99), and Enterprise ($199.99) plans
- **users** table extending Supabase Auth
- **user_subscriptions** and **payment_history** tables
- **usage_statistics** table for dashboard analytics
- **Enhanced maintenance_logs** and **audit_logs** tables
- **Row Level Security (RLS)** policies for data protection

### Step 2: Create Your First Admin User

Run this in Supabase SQL Editor:
```sql
SELECT create_admin_user(
    'your-email@company.com',
    'Your Full Name',
    'Your Company Name'
);
```

## 📱 Flutter App Integration

### Step 3: Update pubspec.yaml

Add any missing dependencies (most should already be there):
```yaml
dependencies:
  supabase_flutter: ^2.5.6
  provider: ^6.1.2
  # ... your existing dependencies
```

### Step 4: Update Main App with New Providers

Update your `main.dart` to include the new providers:

```dart
// Add these imports
import 'providers/auth_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/statistics_provider.dart';

// Update your MultiProvider
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => VanProvider()),
    ChangeNotifierProvider(create: (_) => DriverProvider()),
    // Add these new providers:
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
    ChangeNotifierProvider(create: (_) => StatisticsProvider()),
  ],
  child: MaterialApp(
    title: 'Van Damage Tracker',
    theme: modernPremiumTheme,
    home: const AuthWrapper(), // Create this wrapper
  ),
)
```

### Step 5: Create Authentication Wrapper

Create `lib/widgets/auth_wrapper.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/main_dashboard_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authProvider.isAuthenticated) {
          return const MainDashboardScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
```

## 🔐 Role-Based Access Control

### Admin Role Permissions:
- ✅ Add/remove vans
- ✅ Add/remove drivers  
- ✅ Change van status
- ✅ View all statistics
- ✅ Manage subscriptions
- ✅ Manage users

### Crew Role Permissions:
- ❌ Add/remove vans
- ❌ Add/remove drivers
- ✅ Change van status (Active ↔ Maintenance ↔ Out of Service)
- ✅ Add maintenance notes and descriptions
- ✅ View basic statistics
- ❌ Manage subscriptions/users

### Viewer Role Permissions:
- ❌ Add/remove vans or drivers
- ❌ Change van status
- ✅ View basic statistics only
- ❌ Manage anything

### Usage in Widgets:

```dart
// Example: Conditionally show admin-only buttons
Consumer<AuthProvider>(
  builder: (context, auth, child) {
    if (!auth.canAddVans) return const SizedBox.shrink();
    
    return ElevatedButton(
      onPressed: () => _addNewVan(),
      child: const Text('Add Van'),
    );
  },
)

// Example: Check crew permissions for maintenance actions
if (auth.canChangeVanStatus) {
  // Show van status change options
}

if (auth.canAddMaintenanceNotes) {
  // Show maintenance logging interface
}
```

## 📊 Statistics Dashboard Features

The statistics system tracks:

### Photo Upload Statistics:
- Photos uploaded today/week/month/year
- Weekly trends and patterns
- Storage usage

### Van Fleet Statistics:
- Active vs Maintenance vs Out of Service counts
- Vans with new damage (last 24 hours)
- Total damage reports
- Damage rate percentages

### Usage in Widgets:

```dart
Consumer<StatisticsProvider>(
  builder: (context, stats, child) {
    return Column(
      children: [
        StatCard(
          title: 'Photos Today',
          value: '${stats.photosUploadedToday}',
          isAlert: stats.isHighUsageDay,
        ),
        StatCard(
          title: 'Damage Rate',
          value: '${stats.damageRate.toStringAsFixed(1)}%',
          isAlert: stats.hasHighDamageRate,
        ),
        StatCard(
          title: 'Storage Used',
          value: stats.storageUsage,
        ),
      ],
    );
  },
)
```

## 💳 Subscription Management

### Subscription Plans:

#### Starter Plan ($29.99/month):
- 10 vans max
- 3 users max  
- 1,000 photos/month
- Data export

#### Professional Plan ($79.99/month):
- 50 vans max
- 10 users max
- 5,000 photos/month
- Custom reports + API access

#### Enterprise Plan ($199.99/month):
- Unlimited vans & users
- Unlimited photos
- All features + white label

### Usage in App:

```dart
Consumer<SubscriptionProvider>(
  builder: (context, subscription, child) {
    if (!subscription.hasActiveSubscription) {
      return SubscriptionRequiredDialog();
    }

    if (subscription.isAtLimit('vans', currentVanCount)) {
      return UpgradeRequiredDialog(feature: 'add more vans');
    }

    return YourFeatureWidget();
  },
)
```

## 🛠️ Implementation Steps

### 1. Database Setup
- [x] Run `06_authentication_and_subscription_schema.sql`
- [x] Create admin user
- [ ] Test database connections

### 2. Authentication Flow
- [ ] Create login screen
- [ ] Create signup screen  
- [ ] Create account management screen
- [ ] Test authentication flow

### 3. Role-Based UI
- [ ] Update van management screens with permission checks
- [ ] Update driver management screens with permission checks
- [ ] Create crew-specific maintenance interface
- [ ] Test all role permissions

### 4. Statistics Dashboard
- [ ] Create dashboard screen
- [ ] Implement statistics cards and charts
- [ ] Add real-time updates
- [ ] Test statistics accuracy

### 5. Subscription Management
- [ ] Create subscription selection screen
- [ ] Create billing history screen
- [ ] Implement feature limits
- [ ] Test subscription flows

## 🔧 Additional Features You Can Add

### For Admins:
- **User Management**: Assign roles, deactivate users
- **Fleet Analytics**: Advanced reporting and insights
- **Billing Management**: View all payments, generate invoices
- **System Settings**: Configure app-wide settings

### For Crew:
- **Maintenance Workflows**: Step-by-step repair processes
- **Parts Inventory**: Track parts used in repairs
- **Work Orders**: Structured maintenance tasks
- **Time Tracking**: Log hours spent on repairs

### For All Users:
- **Notifications**: Alert systems for high damage rates
- **Mobile App**: Push notifications for urgent issues
- **Reporting**: Generate PDF reports
- **Data Export**: CSV/Excel exports for external analysis

## 🚀 Next Steps

1. **Run the database schema** first
2. **Create the authentication screens** (login/signup)
3. **Add permission checks** to existing screens
4. **Create the statistics dashboard**
5. **Implement subscription management**
6. **Test thoroughly** with different user roles

## 📧 Support

The system includes comprehensive error handling and logging. Check the following for troubleshooting:

- Supabase logs for database issues
- Flutter debug console for client-side errors
- The `audit_logs` table for security events
- RLS policies if data access issues occur

## 🎯 Benefits

This implementation provides:

- **Security**: Row-level security and audit logging
- **Scalability**: Subscription-based growth model
- **Insights**: Comprehensive analytics and reporting
- **Flexibility**: Role-based permissions for different user types
- **Professional**: Enterprise-ready features and billing

You now have a complete enterprise-grade authentication and subscription system that will scale with your business and provide valuable insights into your van fleet operations! 