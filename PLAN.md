# Aeternum App — AI Agent Feature Plan
> Last updated from full codebase scan — April 2026

---

## What Aeternum Is

A **couples-focused Flutter app** with period tracking at its core, extended with shared productivity tools.
The new feature being added: **Aeternum Agent** — a local AI agent that monitors Google Classroom,
notifies on new work, automates school tasks, and can control the phone on the user's behalf.

---

## Codebase Scan Findings (answers all open questions)

### ✅ Already have — no reinstall needed
| What | Where | Impact on Agent |
|---|---|---|
| `google_sign_in ^6.3.0` | pubspec.yaml | Extend scopes to include Classroom API |
| `speech_to_text ^7.3.0` | pubspec.yaml | Voice input already available |
| `flutter_local_notifications ^17.0.0` | pubspec.yaml | Notifications ready to use |
| `hive ^2.2.3` + `hive_flutter` | pubspec.yaml | Local state storage ready |
| `http ^1.6.0` | pubspec.yaml | REST calls to Classroom API ready |
| `provider ^6.0.5` | pubspec.yaml | State management — use this, no new library |
| `shared_preferences ^2.5.4` | pubspec.yaml | Simple key-value persistence |
| `timezone ^0.9.2` | pubspec.yaml | Scheduled notifications ready |
| Firebase Auth + Firestore | main.dart | Auth layer exists |
| AI services pattern | `eri_ai_service.dart`, `aero_ai_service.dart` | Follow same pattern for Agent |
| AI bubble widgets | `eri_chat_bubble.dart`, `aero_chat_bubble.dart` | Reuse/adapt for Agent chat UI |
| Features page grid | `screens/features_page.dart` | Add Agent card here |
| Root screen (5 tabs) | `screens/root_screen.dart` | Agent screen plugs in as a push route from Features |

### ⚠️ Needs to be added
| What | Why |
|---|---|
| `flutter_tts` | TTS not yet in pubspec — needed for voice output |
| `flutter_background_service` | No background polling exists yet |
| `android_intent_plus` | App launching (phone agent tools) |
| `device_calendar` | Calendar write access |
| `googleapis` Dart package | Google Classroom API typed client |
| `extension_google_sign_in_as_googleapis_auth` | Bridge google_sign_in → googleapis auth |
| Gemma 4 integration | `flutter_gemma` plugin (ML Kit GenAI wrapper) |
| Android Accessibility Service | Phase 5 only — native Kotlin module |

### 🔍 Key Architecture Observations
- **State management**: Provider — all Agent state goes through `ChangeNotifier` providers
- **Navigation**: `RootScreen` uses `IndexedStack` + custom bottom nav (5 tabs).
  Agent screen is NOT a 6th tab — it launches from the Features page card (push route),
  same pattern as Class Schedule, Budget Planner, etc.
- **Existing AI pattern**: Eri and Aero are stateless service classes that call an external API.
  The new Agent will follow the same service class pattern but call Gemma 4 locally.
- **Google Sign-In**: Already wired to Firebase Auth. For Classroom API, the same
  `google_sign_in` instance needs additional OAuth2 scopes added.
- **Features page**: `_FeatureCardData` grid — add Agent as a new card entry.
  Follows exact same pattern as existing cards.
- **No flutter_tts in pubspec** — must add for voice output.
- **No background service** — must add `flutter_background_service` for Classroom polling.
- **Music player already uses a background audio service** — background service setup
  will need to coexist with `audio_service`. Handle channel conflicts carefully.
- **Role system**: App has boyfriend/girlfriend roles. Agent features apply to both roles.
- **Firestore is used for sync** — Classroom data stays local only (not synced to Firestore).

---

## Architecture

```
┌────────────────────────────────────────────────────────────┐
│                    Aeternum App (existing)                  │
│                                                            │
│  Features Page ──► [+ Agent Card] ──► AgentScreen (push)  │
│                                             │              │
│                              ┌──────────────▼───────────┐  │
│                              │      AgentProvider        │  │
│                              │   (ChangeNotifier)        │  │
│                              └──┬──────────┬────────────┘  │
│                                 │          │               │
│                    ┌────────────▼┐    ┌────▼─────────────┐ │
│                    │ AgentBrain  │    │  AgentChatState  │ │
│                    │ (service)   │    │  (messages, UI)  │ │
│                    └──────┬──────┘    └──────────────────┘ │
│                           │                                │
│          ┌────────────────┼─────────────────────┐         │
│          │                │                     │         │
│   ┌──────▼──────┐  ┌──────▼──────┐  ┌──────────▼──────┐  │
│   │ Classroom   │  │ Gemma4      │  │  PhoneTools     │  │
│   │ Monitor     │  │ Service     │  │  (intents, cal, │  │
│   │ (bg service)│  │ (local AI)  │  │   notifs, TTS)  │  │
│   └─────────────┘  └─────────────┘  └─────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

---

## New Files to Create

```
lib/
  agent/
    agent_brain.dart              ← orchestrator: parses intent, calls tools
    agent_provider.dart           ← ChangeNotifier for UI state
    tool_registry.dart            ← maps tool names → dart functions
    prompt_templates.dart         ← system prompts per task type

    classroom/
      classroom_service.dart      ← Google Classroom REST API calls
      classroom_monitor.dart      ← background polling logic
      classroom_state.dart        ← Hive-backed last-seen state
      models/
        classroom_assignment.dart
        classroom_announcement.dart

    gemma/
      gemma_service.dart          ← flutter_gemma wrapper
      gemma_inference_isolate.dart ← run inference off main thread

    phone_tools/
      app_launcher.dart           ← android_intent_plus
      notification_tool.dart      ← flutter_local_notifications
      calendar_tool.dart          ← device_calendar
      tts_tool.dart               ← flutter_tts

    voice/
      stt_service.dart            ← wraps existing speech_to_text pkg
      tts_service.dart            ← wraps flutter_tts

    automations/
      school_automator.dart       ← deadline alerts, morning briefing
      automation_scheduler.dart   ← triggers based on time/events

  screens/
    agent_screen.dart             ← main Agent UI (push from Features)
    widgets/
      agent_chat_bubble.dart      ← adapted from eri_chat_bubble.dart
      agent_status_card.dart      ← shows Classroom sync status
      voice_fab.dart              ← floating mic button

android/
  app/src/main/kotlin/.../
    AccessibilityAgentService.kt  ← Phase 5 only
```

---

## Files to Modify (existing)

| File | Change |
|---|---|
| `pubspec.yaml` | Add: flutter_tts, flutter_background_service, android_intent_plus, device_calendar, googleapis, extension_google_sign_in_as_googleapis_auth, flutter_gemma |
| `screens/features_page.dart` | Add Agent `_FeatureCardData` card to the grid |
| `screens/login_page.dart` | Add Classroom OAuth2 scopes to `google_sign_in` config |
| `main.dart` | Register background service on startup |
| `android/app/src/main/AndroidManifest.xml` | Permissions: RECEIVE_BOOT_COMPLETED, FOREGROUND_SERVICE, READ_CALENDAR, WRITE_CALENDAR + Accessibility service entry (Phase 5) |

---

## Implementation Phases

### Phase 1 — Classroom Monitor + Notifications (Week 1)
Goal: Detect new assignments and fire a notification. No AI yet.

- [ ] Add new pubspec dependencies (non-Gemma ones first)
- [ ] Add Classroom API OAuth2 scopes to existing `google_sign_in` config
- [ ] `classroom_service.dart` — fetch courses, coursework, announcements
- [ ] `classroom_state.dart` — Hive box stores last-seen IDs per course
- [ ] `classroom_monitor.dart` — background service, polls every 15 min
- [ ] On new item: fire plain local notification via existing `flutter_local_notifications`
- [ ] `agent_screen.dart` — basic screen with Classroom sync status card
- [ ] Add Agent card to `features_page.dart` grid

### Phase 2 — Gemma 4 Local AI (Week 2)
Goal: Smart summaries in notifications + basic chat.

- [ ] Add `flutter_gemma` to pubspec
- [ ] `gemma_service.dart` — load E4B model, run prompts
- [ ] `prompt_templates.dart` — summarization prompt for assignments
- [ ] Wire Gemma into monitor: new item → summarize → smart notification
- [ ] `agent_chat_bubble.dart` — adapted from `eri_chat_bubble.dart`
- [ ] Chat UI in `agent_screen.dart` — user types, agent replies using Gemma
- [ ] `agent_provider.dart` — manages chat message state via `ChangeNotifier`

### Phase 3 — Voice + Basic Phone Tools (Week 3)
Goal: Talk to it, let it launch apps and set reminders.

- [ ] `stt_service.dart` — wrap existing `speech_to_text` package
- [ ] `tts_service.dart` + `tts_tool.dart` — add `flutter_tts`, speak responses
- [ ] `voice_fab.dart` — floating mic button on agent screen
- [ ] `tool_registry.dart` — maps tool names to dart functions
- [ ] `agent_brain.dart` — Gemma function calling: parse intent → call tool
- [ ] `app_launcher.dart` — `android_intent_plus` to open apps by package name
- [ ] `notification_tool.dart` — agent-triggered reminders
- [ ] `calendar_tool.dart` — write deadlines to device calendar
- [ ] Test: "Open Google Classroom" → agent launches it

### Phase 4 — School Automations (Week 4)
Goal: Agent acts proactively without being asked.

- [ ] `school_automator.dart` — deadline proximity logic (2d, 1d, same day alerts)
- [ ] `automation_scheduler.dart` — time-based triggers
- [ ] Morning briefing (7am): list today's deadlines, summarize pending work via TTS
- [ ] Auto-calendar sync: new Classroom deadline → auto-add to device calendar
- [ ] Integrate with existing Study Planner (`study_planner/`) if deadline overlaps

### Phase 5 — Full Phone UI Control (Later)
Goal: Agent taps and navigates apps like a human.

- [ ] `AccessibilityAgentService.kt` — Kotlin accessibility service
- [ ] Platform channel: expose `readScreen()`, `tap(x,y)`, `inputText()` to Flutter
- [ ] Wire into `agent_brain.dart` tool registry
- [ ] ⚠️ User must grant Accessibility permission manually
- [ ] ⚠️ HyperOS (Redmi Turbo 5 Max) may add extra permission hoops — test carefully

---

## Constraints & Risk Notes

### Google Classroom API
- Existing `google_sign_in` handles auth — add scopes:
  `classroom.courses.readonly`, `classroom.coursework.me.readonly`,
  `classroom.announcements.readonly`
- Users must be signed in with their school Google account
- API quota: 500 req/100 sec per user — 15-min polling is well within limit
- **Risk**: If user's school restricts third-party OAuth apps, Classroom API access
  may be blocked by the school's Google Workspace admin. No workaround for this.

### Background Service vs Audio Service
- App already uses `audio_service` for music background
- Adding `flutter_background_service` must use a **different foreground service channel**
- Do NOT reuse `com.aeternum.audio` notification channel ID
- Use `com.aeternum.agent` as the agent background service channel

### Gemma 4 on Dimensity 9500s
- NPU 890 handles inference — won't stress CPU
- E4B model (~2.5GB) — first download on WiFi, stored in app's files directory
- Load time on first launch: ~10-15 sec. Show a loading state in UI.
- Run inference in an isolate (`gemma_inference_isolate.dart`) to keep UI thread smooth

### Provider Integration
- All new agent state goes through `AgentProvider extends ChangeNotifier`
- Register in `main.dart` alongside existing providers
- Do NOT use Riverpod or Bloc — stay consistent with existing codebase

### HyperOS Restrictions (Redmi Turbo 5 Max specific)
- HyperOS has aggressive battery optimization — user must whitelist the app
- Show a one-time setup prompt guiding user to Settings > Battery > No restrictions
- Accessibility Service (Phase 5) may need additional HyperOS-specific permissions

---

## Package Additions Summary

```yaml
# Add to pubspec.yaml dependencies:
flutter_tts: ^4.2.0
flutter_background_service: ^5.0.9
android_intent_plus: ^5.2.0
device_calendar: ^4.3.5
googleapis: ^13.2.0
extension_google_sign_in_as_googleapis_auth: ^2.0.12
flutter_gemma: ^0.2.0          # ML Kit GenAI wrapper for Gemma on-device
```

---

## Entry Point for Coding

Start at **Phase 1, Step 1**: update `pubspec.yaml` with non-Gemma dependencies first,
then wire `classroom_service.dart` with the existing `google_sign_in` instance.
Do NOT touch existing tracker, budget, schedule, or messaging modules.
