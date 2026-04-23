# TrackOn Fitness App - Structure & Features

## Overview

A comprehensive Flutter-based fitness and running mobile app with 4 main tabs: Home, Run, Fitness, and Groups.

## Project Structure

### 1. **Home Tab** (`lib/pages/home_page.dart`)

Main dashboard showcasing user's fitness journey.

**Features:**

- **Profile Section**: Clickable profile picture in top-right corner
  - Opens modal with user profile menu
  - Access to Settings, Profile, Notifications, Help & Support, Logout
- **Progress Charts**: Interactive line chart showing weekly activity progression
  - Displays trends over 7 days
  - Y-axis: Activity units (km/kcal)
  - X-axis: Days of the week
- **Stats Cards**: Two key metrics
  - Total Steps (12.5k example)
  - Calories Burned (580 kcal example)
- **Today's Plan**: List of workouts scheduled for today
  - Shows 3 sample workouts
  - Color-coded by intensity
  - Checkbox to mark completion
  - Displays duration and intensity level

### 2. **Run Tab** (`lib/pages/run_page.dart`)

Dedicated running tracking interface with real-time metrics.

**Features:**

- **Map Placeholder**: Shows current location
  - Center latitude/longitude display
  - Ready for Google Maps integration
- **Real-time Stats**:
  - Duration timer (MM:SS format)
  - Distance tracking (km)
- **Control Buttons**:
  - Play/Pause button (starts/stops run)
  - History button (view past runs)
  - Settings button
  - Finish Run button (completes and saves session)
- **Running History Sheet**:
  - Shows past run records
  - Displays date, duration, distance, pace
  - Scrollable list of all previous runs

### 3. **Fitness Tab** (`lib/pages/fitness_page.dart`)

Workout management with two sub-sections.

#### 3a. **My Workouts**

- List of user's routine workouts
- Organized by days (Monday, Wednesday, Friday)
- Each workout shows:
  - Title and color-coded icon
  - Number of exercises
  - Duration in minutes
  - Assigned day
- Click to view detailed workout info:
  - Full exercise list with sets/reps
  - Video tutorial placeholder
  - Start Workout button

#### 3b. **Workout Library**

- Browse all available workouts from database
- **Category Filter**: Quick filter by type
  - All, Strength, Cardio, Flexibility, HIIT
- Each workout card shows:
  - Exercise count
  - Duration
  - Category tag
  - Add button to add to personal workouts
- Click on any workout to see:
  - Detailed exercise breakdown (sets/reps)
  - Video tutorial section
  - Full workout information

### 4. **Groups Tab** (`lib/pages/groups_page.dart`)

Social features and community engagement with three sub-sections.

#### 4a. **Feed**

- Social feed from followed clubs and friends
- Features:
  - Author information (name, avatar, timestamp)
  - Post content with emojis
  - Like count
  - Comment count
  - Action bar (Like, Comment, Share)
- Sample posts showcasing:
  - Personal achievements (e.g., "Just completed a 10k run")
  - Club challenges
  - Workout motivation posts

#### 4b. **Clubs**

- **Search Bar**: Find clubs quickly
- **My Clubs**: Already followed clubs
  - Shows membership count
  - Category/type of club
  - Follow status indicator
- **Recommended Clubs**: Suggested clubs based on interests
  - Mountain climbing, Yoga, HIIT, Cycling clubs
  - Follow/Unfollow buttons
  - Member count and category info

#### 4c. **Friends**

- **Friends List**: All connected friends
  - Online status indicator (green dot)
  - Last seen timestamp
  - Quick action buttons (Message, Call)
- **Friend Detail View** (tap to expand):
  - Profile avatar with status
  - This week's activity stats:
    - Number of runs
    - Number of workouts
  - Message and Add to Challenge buttons

## Color Scheme

Primary Colors:

- **Purple**: `#6B5FFF` - Primary brand color
- **Orange**: `Colors.orange` - Cardio/Running
- **Blue**: `Colors.blue` - Strength/Chest
- **Green**: `Colors.green` - Flexibility/Yoga
- **Red**: `Colors.red` - HIIT/Intense

## Key Dependencies

```yaml
fl_chart: ^0.65.0 # Charts and graphs
intl: ^0.19.0 # Date/time formatting
```

## Navigation Structure

```
MainNavigation (BottomNavigationBar)
├── Home Page
│   ├── Profile Menu (Modal)
│   ├── Progress Chart
│   ├── Stats Cards
│   └── Today's Workouts
├── Run Page
│   ├── Map View
│   └── Running History (Modal)
├── Fitness Page
│   ├── My Workouts Tab
│   │   └── Workout Detail (Modal)
│   └── Workout Library Tab
│       └── Workout Detail (Modal)
└── Groups Page
    ├── Feed Tab
    │   └── Posts List
    ├── Clubs Tab
    │   ├── Search Bar
    │   ├── My Clubs List
    │   └── Recommended Clubs
    └── Friends Tab
        └── Friends List
            └── Friend Detail (Modal)
```

## Running the App

```bash
# Get dependencies
flutter pub get

# Run on device/emulator
flutter run

# Run for specific platform
flutter run -d <device-id>

# Build APK
flutter build apk

# Build iOS
flutter build ios
```

## Features Ready for Enhancement

1. **Backend Integration**: Connect to Firebase/API for real data
2. **Maps Integration**: Implement Google Maps for run tracking
3. **Video Playback**: Add video tutorial playback in workouts
4. **Push Notifications**: Enable workout reminders
5. **Authentication**: Add login/signup flow
6. **Data Persistence**: Local database for offline support
7. **Sharing**: Social sharing of achievements
8. **Stats Analytics**: Advanced workout analytics and trends
9. **Wearable Integration**: Connect with fitness wearables
10. **Dark Mode**: Add dark theme support

## Notes

- All data is currently mock/placeholder for UI/UX demonstration
- No backend connectivity required for this version
- App is fully functional for navigation and UI interactions
- Ready for backend/API integration when development progresses
