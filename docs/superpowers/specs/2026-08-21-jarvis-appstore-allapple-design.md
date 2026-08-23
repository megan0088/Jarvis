# Jarvis — All-Apple Companion — Product & App Store Spec

- Date: 2026-08-21
- Status: Draft (menunggu review user)
- Product: **Jarvis** — an on-device, OMNI-style AI companion for **macOS**, built entirely on Apple frameworks.
- Distribution goal: **Mac App Store**.

## 1. Vision & positioning

Jarvis is a friendly desktop companion: a living 3D character (Buddy Mode) plus an AI chat that helps with wellness (hydration/stretch/meals reminders), day summaries, and light Q&A — all **on-device, private, zero-setup**. It is Apple's answer to ASUS OMNI, adapted to the Mac: same "companion + local AI + reminders + emoting character" experience, delivered through Apple's own stack (no third-party runtime, no external server).

**Core principle — all-Apple:** the shipping product depends only on Apple frameworks. The LLM is **Foundation Models (Apple Intelligence)**. Ollama support stays in the codebase as a **dev-only/dormant** path (not in the App Store build path; no `network.client` entitlement shipped).

## 2. Goals / Non-goals

### Goals
- A macOS app that is **App Store submittable** (sandbox, privacy manifest, no placeholders, licensed assets).
- On-device AI chat via Foundation Models with a warm persona.
- A **clean Buddy Mode**: only the living 3D virtual pet on the desktop — no stats, no control clutter.
- Wellness reminders created by natural language, with notifications.
- HIG dashboard, **responsive** across window sizes.

### Non-goals
- No AniMe Matrix / ASUS-hardware features (irrelevant on Mac).
- No third-party AI runtime in the shipping product (Ollama dormant only).
- iOS App Store submission is out of scope for this spec (macOS first; legacy iOS code stays guarded, not shipped as an iOS product now).

## 3. Target & requirements

- macOS 26+ (Tahoe), Apple Silicon.
- **Apple Intelligence** required for the chat feature. If unavailable/disabled, the app remains fully usable (character, reminders, wellness, dashboard) and the chat surface shows a clear "Enable Apple Intelligence" state instead of failing silently.
- App Sandbox + Hardened Runtime: **already enabled**. All-Apple means **no `network.client` needed**.

## 4. Architecture

Matches **Taggo** shape (per user decision), already in place:
```
Jarvis/
├── App/               # JarvisApp (@main), JarvisApp+macOS; (adopt AppDependencies DI — see below)
├── Infrastructure/
│   ├── Persistence/   # PetStore
│   └── Services/      # AppleBrain (Foundation Models), OllamaBrain (dormant), Brain, BrainTypes,
│                      #   ReminderIntent, WellnessNotificationCenter, Haptics, JarvisBuddyWindowController
├── Presentation/
│   ├── ViewModels/    # ChatStore
│   └── Views/         # all SwiftUI views (flat), incl. RobotCharacterView
└── Resources/         # Robot.usdz
```
- **DI:** adopt a Taggo-style `AppDependencies` struct (`.live` + `makeXViewModel()` factories) as a small refactor so wiring matches Taggo. (Roadmap item, not an MVP blocker.)
- **#if os()** guards retained so the multiplatform target still compiles for iOS (legacy), but the App Store product is the macOS app.

## 5. Feature set & phasing

Everything is all-Apple. Ship MVP first; layer the rest via updates.

| Feature | Apple framework | Phase |
|---|---|---|
| AI chat (persona, streaming, multi-turn) | **Foundation Models** | **MVP** ✅ built |
| Reminder-by-chat (NL → schedule + notify) | ReminderIntent + **UserNotifications** | **MVP** ✅ built |
| Wellness dashboard (manual water/stretch/meal) + screen time | SwiftUI + PetStore | **MVP** ✅ built |
| HIG dashboard, **responsive** | SwiftUI (`NavigationSplitView`, adaptive grid) | **MVP** (polish) |
| **Buddy Mode — clean living 3D pet** | **RealityKit** (Robot.usdz) | **MVP** 🟡 in progress |
| Apple-Intelligence-unavailable graceful state | Foundation Models availability | **MVP** |
| Real health data (hydration/steps/stand) | **HealthKit** | v1.x |
| Audio transcription + summary | **Speech / SpeechAnalyzer** + Foundation Models | v1.x |
| Voice commands | Speech + **App Intents / Siri** | v1.x |
| Writing help | **Writing Tools** | v1.x |
| Document Q&A (Librarian) | **PDFKit** + Foundation Models | v1.x |
| Character customization (hats/outfits) | RealityKit attachments + **Genmoji / Image Playground** | v1.x |
| Cross-device sync | **iCloud / CloudKit** | v1.x |
| Widgets / Live Activities | **WidgetKit / ActivityKit** | v1.x |
| Menu-bar presence | **MenuBarExtra** | v1.x |
| Feature discovery | **TipKit** | v1.x |
| Mini-games / gallery | SpriteKit/SwiftUI | later (optional) |

## 6. Key components (MVP)

- **AI brain — `AppleBrain` (Foundation Models):** `LanguageModelSession(instructions: persona)`, `streamResponse`, cumulative streaming into `ChatStore`. Persona = warm wellness companion (English). `availability()` maps to a clear UI state when AI is off. `OllamaBrain` remains but is **not** selectable in the App Store build (no network entitlement → its `availability()` returns needsSetup → never chosen); optionally hidden behind a dev flag.
- **Character — `RobotCharacterView` (RealityKit):** loads `Robot.usdz`, plays baked idle animation ("Take_001"), gentle transform motion; face is a single material (no separate expression rig) → "aliveness" via idle + motion + optional overlay. Reused in Buddy Mode.
- **Buddy Mode — `JarvisBuddyWindowController` (clean):** transparent floating panel hosting `RobotCharacterView` only. **Remove all stat/demo/reset buttons.** Exit via a subtle affordance (Esc and/or a small hover-revealed close) — no visible control row. Click-through everywhere except the exit affordance.
- **Reminders:** `ReminderIntent.parse` → `PetStore.customSchedules` (persisted) → `WellnessNotificationCenter` (UserNotifications).
- **Dashboard:** HIG `NavigationSplitView` + cards, **responsive** (see §8).

## 7. Buddy Mode — clean design (locked)

- Only the living 3D pet floats on the desktop (bottom-right by default).
- No statistics, no reminder-trigger buttons, no reset buttons in the buddy window.
- Idle animation always on; subtle bob/look-at optional.
- Exit: `Esc` key and/or a small close control that appears only on hover near the pet.
- Reminder popups (if shown in buddy) appear as a small speech bubble near the pet — deferred to v1.x; MVP buddy is purely the living pet.

## 8. Responsive design requirements (MVP)

- `NavigationSplitView` sidebar collapses on narrow widths; set sensible `minWidth`/`idealWidth` for window and panes.
- Card grid uses `LazyVGrid(.adaptive(minimum:))` and reflows.
- Support Dynamic Type; test light/dark.
- Chat sheet/pane sizes adapt; no fixed layouts that clip on small windows.

## 9. App Store — Definition of Done (compliance)

- [ ] Remove all placeholder/"coming soon" content (e.g., `DashboardTemplate` "History coming soon." → implement History or remove the nav item).
- [ ] Add `PrivacyInfo.xcprivacy` (declare: no tracking; local-only data; notification usage).
- [ ] Set `INFOPLIST_KEY_LSApplicationCategoryType` (e.g., `public.app-category.productivity` or `.lifestyle`).
- [ ] Keep App Sandbox + Hardened Runtime ON; **do not** add `network.client` (all-Apple). Keep existing app-groups/kvstore entitlements as needed.
- [ ] Ollama removed from the shipping selectable path (dormant/dev-only).
- [ ] **Asset attribution**: credit `Robot.usdz` author (Sketchfab, badd / @l0wpoly, Free Standard) in an in-app Acknowledgments screen; confirm license permits app distribution.
- [ ] No medical claims in wellness copy.
- [ ] App icon (all sizes), and clean English copy throughout the macOS UI (legacy Indonesian demo strings in `ContentView` are iOS-path only; ensure they never surface on macOS).
- [ ] Apple Developer Program account + signing + App Store Connect record.
- [ ] Privacy policy URL, screenshots, description, keywords, age rating.
- [ ] TestFlight pass, then submit.

## 10. Error / availability handling

- Apple Intelligence unavailable → chat surface shows an explanatory card + a button to open System Settings; the rest of the app works.
- Notification permission denied → reminders still tracked in-app; prompt to enable notifications.
- Model load failure (character) → fallback to a simple placeholder avatar; never crash.

## 11. Testing

- Unit (Swift Testing): `ReminderIntent` parsing, `ChatStore` streaming/fallback (with stub brain), `OllamaWire` (kept). `AppleBrain.buildPrompt`.
- Manual: chat with Apple Intelligence on; AI-off state; Buddy Mode clean render + exit; responsive resize; dark mode.
- Pre-submit: sandboxed archive build runs; no console entitlement violations.

## 12. Risks & open questions

- **Foundation Models capability/context limits** — validate the companion chat quality on-device; keep prompts concise.
- **Apple Intelligence gating** — a meaningful share of Macs may not have it; the app must be valuable without chat (character + reminders + wellness).
- **RealityKit buddy transparency/framing** — needs visual verification (pending).
- Open: does History get implemented (MVP) or removed? (Spec assumes **removed** for MVP to avoid placeholder.)
- Open: adopt `AppDependencies` DI in MVP or v1.x? (Spec assumes **v1.x** unless trivial.)
