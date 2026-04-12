# Walking Buddy

Commuter trip logging and route insight app built with Flutter.

Walking Buddy helps users submit commute details, import real locations from Google Maps, and view a rich trip summary with route stats and map context.

---

## Highlights

- Beautiful multi-section Flutter UI for trip submission and records
- Google-powered location import from typed station/place names
- Route and map summary flow after trip submission
- Local-first persistence with SQLite (`sqflite`)
- Desktop + mobile support in a single codebase
- In-app Google API health warning to quickly spot key/config issues

---

## Core Features

### 1) Trip Submission
- Capture commuter details (name, start, destination, route, mode, fare, crowd, comfort)
- Fast validation and save flow
- Auto-import location coordinates from Google endpoints

### 2) Trip Summary
- Opens immediately after submit
- Uses imported coordinates for route/map display
- Displays route and commute metrics

### 3) Smart Place Resolution
- Multi-step Google lookup strategy:
	- Find Place From Text
	- Places Autocomplete
	- Places Text Search
	- Geocoding fallback
- Designed to handle ambiguous station names better

### 4) Local Database
- SQLite-backed storage for submissions and supporting records
- Works offline for core logging flow

### 5) Impact/Admin Module
- Includes impact board style data flow and status handling for commuter issues

---

## Tech Stack

- **Framework:** Flutter (Dart)
- **Database:** `sqflite`, `sqflite_common_ffi` (desktop)
- **Maps/UI:** `google_maps_flutter`
- **Networking:** `http`
- **Config:** `flutter_dotenv`
- **Sharing:** `share_plus`
- **Typography:** `google_fonts`

---

## Project Structure

```text
lib/
	main.dart                 # App shell, form flow, theme, API wiring
	api_service_v2.dart       # Google + backend network service layer
	trip_summary_page_v2.dart # Summary view with map/route/stat rendering
	database_helper.dart      # SQLite schema and data access

android/
	app/src/main/AndroidManifest.xml  # Android Maps SDK key

.env                        # Runtime API config (not for public repos)
```

---

## Setup

### Prerequisites

- Flutter SDK (stable)
- Android Studio / VS Code
- A Google Cloud project with billing enabled

### 1) Install Dependencies

```bash
flutter pub get
```

### 2) Configure Environment

Create/update `.env`:

```env
GOOGLE_MAPS_API_KEY=YOUR_GOOGLE_WEB_SERVICE_KEY
API_BASE_URL=http://localhost:3000/api
API_TOKEN=test_token_here
APP_NAME=Walking Buddy
APP_URL=https://walkingbuddy.app
```

### 3) Configure Android Maps Key

Set your Android SDK key in:

`android/app/src/main/AndroidManifest.xml`

```xml
<meta-data
		android:name="com.google.android.geo.API_KEY"
		android:value="YOUR_ANDROID_MAPS_KEY" />
```

### 4) Run

```bash
flutter run
```

---

## Google APIs Required

Enable these in Google Cloud for your project:

- Maps SDK for Android
- Geocoding API
- Directions API
- Places API (Legacy) for current endpoint usage

> Recommended: use separate keys for Android SDK and Web Service APIs.

---

## Common Troubleshooting

### `REQUEST_DENIED` from Google APIs

Usually means one of the following:

- API is not enabled in the selected Google Cloud project
- Billing is not enabled
- Key restrictions do not match API usage type
- Wrong key assigned (Android key used for web service calls, or vice versa)

### Location import not working

- Check `.env` key is loaded
- Restart app fully (not just hot reload)
- Confirm in-app warning message status on the form

---

## Roadmap Ideas

- Migrate to Places API (New) / Routes API
- Add richer analytics dashboard for commute trends
- Add backend sync for multi-device shared history
- Add automated tests for route and location resolution flows

---

## Contributing

Contributions, bug reports, and suggestions are welcome.

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Open a pull request

---

## License

No license specified yet. Add a LICENSE file before public/open-source distribution.
