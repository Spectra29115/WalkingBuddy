# Trip Summary Feature Setup Guide

This document explains how to set up and configure the trip summary page feature.

## Overview

The trip summary page displays a detailed view of a completed trip including:
- Trip date, route name, and start/end locations
- Interactive Google Map with custom markers and route visualization
- Statistics: distance, duration, and number of stops
- Community insights: number of commuters on the same route today
- Personal statistics: number of trips logged this month
- Share functionality for native sharing to social media or clipboard

## Architecture

### Components

1. **API Service** (`lib/api_service.dart`)
   - Handles all backend communication
   - Models: `Trip` class for trip data
   - Methods:
     - `fetchTrip(tripId)` - Fetch single trip from backend
     - `fetchCommutorsOnRoute(routeName, date)` - Count commuters on route for specific date
     - `fetchUserTripsThisMonth()` - Count user's trips logged in current month

2. **Trip Summary Page** (`lib/trip_summary_page.dart`)
   - Main UI component displaying the trip summary
   - Handles map rendering with Google Maps Flutter
   - Loads trip data and displays stats/insights
   - Implements share functionality

3. **Routing** (in `lib/main.dart`)
   - Pattern: `/trip/:id/summary`
   - Example: `/trip/12345/summary`

## Backend Requirements

Your backend must provide the following endpoints:

### GET `/api/trips/{tripId}`
Fetch a single trip record.

**Response (200 OK):**
```json
{
  "id": "trip_123",
  "user_id": "user_456",
  "start_name": "Central Station",
  "start_lat": 22.5726,
  "start_lng": 88.3639,
  "end_name": "Airport Terminal",
  "end_lat": 22.6345,
  "end_lng": 88.4465,
  "route_name": "Kolkata Metro Blue Line",
  "submitted_at": "2026-04-12T14:30:00Z"
}
```

**Error Responses:**
- `404 Not Found` - Trip does not exist
- `403 Forbidden` - Trip does not belong to authenticated user

### GET `/api/routes/{routeName}/commuters?date=YYYY-MM-DD`
Count how many unique commuters traveled the given route on the specified date.

**Query Parameters:**
- `date` (string, YYYY-MM-DD format) - The date to query

**Response (200 OK):**
```json
{
  "count": 42,
  "date": "2026-04-12",
  "route_name": "Kolkata Metro Blue Line"
}
```

### GET `/api/user/trips/monthly`
Count how many trips the authenticated user has logged in the current month.

**Response (200 OK):**
```json
{
  "count": 5,
  "month": 4,
  "year": 2026
}
```

## Setup Instructions

### 1. Install Dependencies

The required packages have been added to `pubspec.yaml`:
- `google_maps_flutter: ^2.5.0` - Google Maps rendering
- `http: ^1.1.0` - HTTP requests to backend
- `share_plus: ^7.1.0` - Native share functionality
- `flutter_dotenv: ^5.1.0` - Environment variable loading

Run:
```bash
flutter pub get
```

### 2. Configure Environment Variables

Create a `.env` file in your project root (copy from `.env.example`):

```bash
cp .env.example .env
```

Edit `.env` with your own values:

```
GOOGLE_MAPS_API_KEY=AIzaSyD_5qV...
API_BASE_URL=https://your-backend.com/api
API_TOKEN=your_bearer_token_here
APP_NAME=Walking Buddy
APP_URL=https://walkingbuddy.app
```

### 3. Update pubspec.yaml Assets

Add this to your `pubspec.yaml` under the `flutter:` section to load the .env file:

```yaml
flutter:
  uses-material-design: true
  assets:
    - .env
```

### 4. Initialize Environment in main()

Update your `main()` function to load environment variables:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  await dotenv.load(); // Add this line
  runApp(const DataCollectorApp());
}
```

### 5. Configure Google Maps

#### For Android:
1. Get your Google Maps API key from [Google Cloud Console](https://console.cloud.google.com)
2. Add to `android/app/AndroidManifest.xml`:
   ```xml
   <application>
       <meta-data
           android:name="com.google.android.geo.API_KEY"
           android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
   </application>
   ```

#### For iOS:
1. Add to `ios/Runner/Info.plist`:
   ```xml
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>We need your location to display the map</string>
   <key>com.google.ios.maps.API_KEY</key>
   <string>YOUR_GOOGLE_MAPS_API_KEY</string>
   ```

#### For Web:
Load the Google Maps API in `web/index.html`:
```html
<script async defer
    src="https://maps.googleapis.com/maps/api/js?key=YOUR_GOOGLE_MAPS_API_KEY&libraries=places,directions">
</script>
```

### 6. Update Authentication

In `lib/main.dart`, replace the hardcoded `userId` with your actual authentication mechanism:

```dart
// Before (in _DataCollectorAppState.build):
userId: 'demo_user', // Replace this

// After - get from your auth provider:
userId: _getCurrentUserId(), // Use your auth system
```

## Usage

### Navigating to Trip Summary

From any screen, navigate to the trip summary page using:

```dart
Navigator.of(context).pushNamed('/trip/12345/summary');
```

Or with the MaterialPageRoute directly:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => TripSummaryPage(
      tripId: '12345',
      userId: currentUserId,
      apiService: apiService,
    ),
  ),
);
```

## Error Handling

The trip summary page handles several error cases:

1. **Trip Not Found (404)** - Shows "Trip not found" error message
2. **Unauthorized (403)** - Shows "Unauthorized" error message
3. **Network Error** - Shows "Error loading trip" message
4. **Map Unavailable** - Shows placeholder; all other content still displays
5. **Directions API Failure** - Falls back to straight-line polyline with notification toast

All errors are gracefully handled without crashing the app.

## Map Features

### Markers

- **Start Marker** (Green): Labeled with start location name
  - Click to view info window with full location name

- **End Marker** (Purple/Magenta): Labeled with end location name
  - Click to view info window with full location name

### Route Visualization

- **Primary Route** (if available from Google Directions API):
  - Green polyline (#1D9E75) with 5px stroke weight
  - Shows actual transit directions

- **Fallback Route** (if Directions API unavailable):
  - Same green polyline (#1D9E75)
  - Straight line between start and end
  - Shows "Exact route unavailable — showing estimated path" toast

### Zoom & Centering

- Initial zoom level: 13
- After route loads: Automatically fits entire journey into view using `fitBounds()`

## Statistics Calculation

### Distance

- **From API**: Extracted from `DirectionsResponse.legs[0].distance.text`
- **From Fallback**: Calculated using Haversine formula
  - Marked as "approx." when using fallback calculation

### Duration

- **From API**: Extracted from `DirectionsResponse.legs[0].duration.text`
- **From Fallback**: Shows "—" (not available)

### Stops

- **From API**: Count of `legs[0].steps` array (transit-specific steps)
- **From Fallback**: Shows "—" (not available)

## Share Functionality

The "Share my journey" button uses:

1. **Web Share API** (if available, mostly mobile):
   - Native system share sheet
   - Works with WhatsApp, SMS, email, etc.

2. **Clipboard Fallback** (desktop browsers):
   - Copies to clipboard using `navigator.clipboard.writeText()`
   - Shows "Copied to clipboard" toast for 2 seconds

**Share Message Format:**
```
I just traveled from {start} to {end} on {route}. Tracked with {appName}. {appUrl}
```

Example:
```
I just traveled from Central Station to Airport Terminal on Kolkata Metro Blue Line. Tracked with Walking Buddy. https://walkingbuddy.app
```

## Styling & Theme Support

The trip summary page uses the app's centralized design tokens (`DC` class):

- **Light Mode**: Blue accents, light backgrounds
- **Dark Mode**: Adjusted colors, dark backgrounds
- **Components**: AppCard, consistent typography via Google Fonts (Inter, Barlow)
- **Responsive**: Works on mobile (300px min map height) and desktop (380px min map height)

## Mobile Considerations

- Share button triggers native share sheet on Android and iOS
- Map controls responsive to touch
- Full viewport utilization on mobile devices
- Bottom sheet friendly for long content

## Testing Checklist

- [ ] Backend endpoints return correct data formats
- [ ] API key is valid and not rate-limited
- [ ] Trip not found returns 404
- [ ] Unauthorized trip returns 403
- [ ] Map renders with markers and route
- [ ] Share button works on target platforms
- [ ] Fallback polyline displays when needed
- [ ] Dark mode styling applies correctly
- [ ] No network connection
 handled gracefully
- [ ] Long route names don't break layout

## Troubleshooting

### Map Not Showing

- Check Google Maps API key in configuration
- Verify API key has Maps Static API and Directions API enabled
- Check platform-specific configurations (AndroidManifest, Info.plist)

### Share Button Not Working

- Web Share API requires HTTPS on web (not localhost)
- Clipboard fallback should work on all platforms
- Test on actual device, not just emulator

### Data Not Loading

- Verify backend endpoints are accessible
- Check API_BASE_URL in .env is correct
- Verify authentication token is valid
- Check network connectivity

### Missing Dependencies

Run `flutter pub get` if you see "missing package" errors

## Future Enhancements

Potential improvements to implement:

1. Google Directions API integration for real routing
2. Caching of trip data for offline viewing
3. Real-time transit information
4. Detailed stop-by-stop breakdown
5. Historical trip statistics
6. Export trip as PDF
7. Add photos to trip summary
8. Integration with mobile wallet for tickets
