# Van Damage Tracker Fixes

## Issues Fixed

1. **Column Name Mismatch**: Fixed the `Van` model to properly map camelCase field names to snake_case database columns.
2. **State Management Issue**: Updated `VanProvider` to avoid calling `setState` or `notifyListeners` during build.
3. **Missing RPC Function**: Created a SQL script to add the missing `create_van` function to Supabase.

## Implementation Instructions

### 1. Update the Van Model

In the Van model (`lib/models/van.dart`), we updated the `toJson` and `fromJson` methods to handle the snake_case column names in Supabase:

- Changed `vanNumber` to `van_number` in toJson
- Changed `lastUpdated` to `last_updated` in toJson
- Updated fromJson to support both snake_case and camelCase formats

### 2. Fix State Management in VanProvider

In `lib/services/van_provider.dart`, we:

- Added `isInitialized` flag to track initialization status
- Modified `_initializeDatabase` to use `Future.microtask` to avoid setState during build
- Added proper loading state handling

### 3. Fix HomeScreen Widget

In `lib/screens/home_screen.dart`, we:

- Updated `didChangeDependencies` to use `Future.microtask` to avoid triggering refreshVans during build
- Modified `_checkForNewDamage` to properly handle mounted state and avoid setState during build

### 4. Add Create Van RPC Function

Execute the SQL in `create_van_rpc.sql` on your Supabase database to create the missing function:

```sql
CREATE OR REPLACE FUNCTION public.create_van(van_data JSONB)
RETURNS SETOF vans
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    INSERT INTO public.vans (
        van_number,
        type,
        status,
        date,
        last_updated,
        notes,
        url,
        driver,
        damage,
        rating
    ) VALUES (
        van_data->>'van_number',
        van_data->>'type',
        van_data->>'status',
        van_data->>'date',
        van_data->>'last_updated',
        van_data->>'notes',
        van_data->>'url',
        van_data->>'driver',
        van_data->>'damage',
        (van_data->>'rating')::numeric
    )
    RETURNING *;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_van(JSONB) TO authenticated;
```

## Rebuilding the App

After making these changes:

1. Run `flutter clean` to clear any cache
2. Run `flutter pub get` to ensure dependencies are up to date
3. Rebuild the app with `flutter run`

The app should now properly connect to Supabase, display the vans, and avoid state management errors. 