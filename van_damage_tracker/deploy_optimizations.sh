#!/bin/bash

# Van Fleet App Performance Optimization Deployment Script
# This script applies database optimizations and updates the Flutter app

echo "🚀 Starting Van Fleet Performance Optimization Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the correct directory
if [ ! -f "pubspec.yaml" ]; then
    print_error "Please run this script from the van_damage_tracker directory"
    exit 1
fi

print_status "📁 Current directory: $(pwd)"

# Step 1: Apply database optimizations
print_status "Step 1: Applying database optimizations..."

if [ -f "optimized_van_profiles_view.sql" ]; then
    print_status "Found optimized van profiles view SQL file"
    
    # Check if supabase CLI is available
    if command -v supabase &> /dev/null; then
        print_status "Applying database view via Supabase CLI..."
        supabase db push --include-all
        if [ $? -eq 0 ]; then
            print_success "Database optimizations applied successfully"
        else
            print_warning "Supabase CLI push failed, you may need to apply the SQL manually"
        fi
    else
        print_warning "Supabase CLI not found. Please apply the SQL manually:"
        print_status "Run the SQL in optimized_van_profiles_view.sql in your Supabase dashboard"
    fi
else
    print_error "optimized_van_profiles_view.sql not found"
    exit 1
fi

# Step 2: Update Flutter dependencies
print_status "Step 2: Updating Flutter dependencies..."
flutter pub get
if [ $? -eq 0 ]; then
    print_success "Flutter dependencies updated"
else
    print_error "Failed to update Flutter dependencies"
    exit 1
fi

# Step 3: Clean and rebuild
print_status "Step 3: Cleaning and rebuilding Flutter app..."
flutter clean
flutter pub get

# Step 4: Test the app
print_status "Step 4: Testing the optimized app..."
print_status "You can now run: flutter run --debug"

# Step 5: Performance monitoring
print_status "Step 5: Performance monitoring tips..."
echo ""
print_status "To monitor performance improvements:"
echo "1. Check the console logs for '📦 Returning cached vans' messages"
echo "2. Look for '⚡ Performance: Single query instead of N+1 queries'"
echo "3. Monitor loading times in the app"
echo "4. Check for '🚀 Fetching vans using optimized database view' messages"
echo ""

# Step 6: Fallback instructions
print_status "Step 6: Fallback instructions..."
echo ""
print_warning "If the optimized view doesn't exist, the app will automatically fall back to the original method"
print_warning "You can manually apply the database view by running the SQL in optimized_van_profiles_view.sql"
echo ""

print_success "🎉 Van Fleet Performance Optimization Deployment Complete!"
print_status "The app should now load van and driver profiles much faster"
print_status "Cache will be used for 5 minutes to reduce database calls"
print_status "Run 'flutter run --debug' to test the optimizations" 