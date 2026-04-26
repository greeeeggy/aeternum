# Claude.md — Aeternum App Project Context

> Auto-generated and updated by Claude every session on this project.
> Last updated: 2026-03-20

---

## Project Overview

**Name:** Aeternum  
**Type:** Flutter (Dart) mobile application — couples-focused period tracking app with extended personal productivity features  
**Location:** `C:\projects\aeternum_app`  
**Version:** 2.0.1+5  
**Flutter SDK:** ^3.9.2

---

## Architecture & Structure

```
lib/
├── study_planner/                   # Shared study planner module
│   ├── study_event_model.dart
│   ├── study_planner_service.dart
│   ├── study_planner_page.dart
│   └── add_study_event_dialog.dart
├── main.dart                        # App entry point
├── firebase_options.dart            # Firebase config
├── screens/                         # All page-level screens
│   ├── home_page.dart
│   ├── login_page.dart
│   ├── onboarding_page.dart
│   ├── root_screen.dart
│   ├── role_selection_page.dart
│   ├── period_tracker_page.dart
│   ├── features_page.dart
│   ├── settings_page.dart
│   ├── shared_notes_page.dart
│   ├── note_edit_page.dart
│   ├── messaging_page.dart
│   ├── chat_list_page.dart
│   ├── message_search_page.dart
│   ├── game_page.dart
│   ├── set_special_dates_page.dart
│   ├── app_database.dart
│   └── tracker/                     # Full period tracker module
│       ├── full_period_tracker_page.dart
│       ├── period_tracker_service.dart
│       ├── boyfriend_period_viewer_page.dart
│       ├── partner_sync_service.dart
│       ├── cycle_analytics_service.dart
│       ├── eri_ai_service.dart          # Eri — female AI assistant
│       ├── eri_chat_bubble.dart
│       ├── aero_ai_service.dart         # Aero — male AI assistant
│       ├── aero_chat_bubble.dart
│       ├── ai_context_builder.dart
│       ├── symptom_logging_screen.dart
│       ├── symptom_database_helper.dart
│       ├── symptom_firestore_service.dart
│       ├── symptom_sync_service.dart
│       ├── symptom_summary_card.dart
│       ├── database_helper_extensions.dart
│       └── secret_sex_section.dart
├── budget_planner/                  # Budget planner module
├── class_schedule/                  # Class schedule module
├── features/                        # Music player feature
├── game/tetris/                     # Tetris game
├── image_gallery_feature/           # Encrypted image gallery
├── models/                          # Shared data models
├── services/                        # Shared services (messaging, notes)
├── database/                        # Local message database
└── widgets/                         # Reusable UI widgets
```

---

## Key Features

| Feature | Location | Notes |
|---|---|---|
| Period Tracker | `screens/tracker/` | Core feature; supports partner sync |
| AI Assistants | `eri_ai_service.dart`, `aero_ai_service.dart` | Eri (female), Aero (male) |
| Partner Sync | `partner_sync_service.dart` | Firebase-backed |
| Symptom Logging | `symptom_logging_screen.dart` | Local + Firestore sync |
| Budget Planner | `budget_planner/` | Full CRUD with analytics |
| Class Schedule | `class_schedule/` | With notifications |
| Messaging | `screens/messaging_page.dart` | Real-time Firebase |
| Shared Notes | `screens/shared_notes_page.dart` | Synced via Firebase |
| Music Player | `features/` | Local audio with background service |
| Image Gallery | `image_gallery_feature/` | Encrypted private gallery |
| Tetris Game | `game/tetris/` | Mini-game feature |
| Study Planner | `study_planner/` | Shared academic calendar; Firestore-backed |

---

## Tech Stack

### Frontend
- **Flutter** (Dart) — SDK ^3.9.2
- **Provider** ^6.0.5 — State management
- **table_calendar** — Calendar UI for tracker
- **menstrual_cycle_widget** ^3.10.0 — Core period tracking widget
- **fl_chart** — Analytics charts
- **confetti** — Celebration animations

### Backend / Cloud
- **Firebase Auth** ^6.1.0
- **Cloud Firestore** ^6.1.0
- **Cloud Functions** ^6.0.4 (Node.js in `/functions`)
- **Google Sign-In** + **Facebook Auth**

### Local Storage
- **sqflite** ^2.3.0 — Local relational DB
- **Hive** ^2.2.3 — Key-value store
- **flutter_secure_storage** ^9.2.2 — Encrypted storage
- **shared_preferences** ^2.5.4

### Media & Notifications
- **just_audio** + **audio_service** + **just_audio_background** — Music playback
- **on_audio_query** — Device audio library
- **flutter_local_notifications** ^17.0.0 — Scheduled notifications
- **image_picker** + **flutter_image_compress** + **gal** — Image handling

### Utilities
- **encrypt** ^5.0.3 + **crypto** ^3.0.3 — Encryption
- **speech_to_text** ^7.3.0 — Voice input
- **connectivity_plus** — Network state
- **http** ^1.6.0 — REST calls
- **intl** ^0.19.0 — Localization/date formatting
- **markdown_widget** + **flutter_highlight** — Markdown rendering

---

## Roles / User Types

The app has a **role-based** design:
- **Female user** — Primary period tracker; uses Eri AI assistant
- **Male/Partner user** — Partner view via `boyfriend_period_viewer_page.dart`; uses Aero AI assistant

Role selection happens at `role_selection_page.dart`.

---

## Debugging Rules (CRITICAL)

1. **Always scan for root cause first** — never suggest a fix without identifying the exact problem
2. **No hallucinations** — read the actual file contents before drawing conclusions
3. **Surgical fixes only** — changes must not affect unrelated logic or functionality
4. **Check file before editing** — always read the relevant file(s) before modifying
5. **Respect module boundaries** — tracker, budget, schedule, messaging are isolated modules

---

## Database Layer

| DB | Used For |
|---|---|
| `sqflite` (local) | Budget planner, transactions, savings goals, class schedule |
| `Hive` | Fast key-value caching |
| `Firebase Firestore` | Messaging, shared notes, symptom sync, partner sync |
| `flutter_secure_storage` | Sensitive keys, encrypted gallery access |

---

## Notes & Conventions

- Screens use `StatefulWidget` or `Provider`-based patterns
- AI chat uses bubble widgets (`eri_chat_bubble.dart`, `aero_chat_bubble.dart`)
- Partner sync relies on Firebase — always check connectivity before operations
- Image gallery is **encrypted** — use `encrypt` package properly, never store raw keys
- Notifications use `flutter_local_notifications` with `timezone` for scheduling
- The `packages/` folder has two **local packages**: `menstrual_cycle_widget` and `overlapped_carousel`
- `.bak` file exists for `messaging_page.dart` — treat as backup, not source of truth
- `google_fonts: ^6.2.1` added in session 2026-03-20 for Features page redesign (`Playfair Display` + `Nunito`)
