# Walking Buddy

A beautiful Flutter app for logging and tracking your walking activities with SQLite database storage.

## Features

✨ **Beautiful UI/UX**
- Clean, modern Material Design interface
- Responsive layout that works on all devices
- Intuitive navigation and smooth interactions

📝 **Easy Input**
- Log walk details: name, distance (km), and duration (minutes)
- Form validation to ensure data accuracy
- Simple one-tap entry submission

💾 **SQLite Database**
- Local data persistence
- All your walks saved on your device
- Fast and reliable storage

🗑️ **Manage Entries**
- View all logged walks
- Delete entries with one tap
- Organized list view

## Installation

1. Create a new Flutter project or clone this repository
2. Run: `flutter pub get`
3. Run: `flutter run`

## Dependencies

- sqflite: Local SQLite database
- path: File system path utilities
- intl: Internationalization support

## Usage

1. Open the app
2. Fill in the walk details (name, distance, duration)
3. Tap "Add Entry"
4. View your walks in the list below
5. Delete entries by tapping the delete icon

## Database Schema

```
walk_entries
├── id (INTEGER, Primary Key)
├── name (TEXT)
├── distance (REAL)
├── duration (INTEGER)
└── timestamp (TEXT)
```

---

Happy walking! 🚶‍♂️
