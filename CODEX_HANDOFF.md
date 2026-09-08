# Family Emergency App — Codex Handoff

Last reviewed: 2026-09-09  
Authoritative workspace: `D:\My Projects\family_emergency_app`  
Current branch: `main`  
Current HEAD at this update: `4e08667` (`New UI Design + New Structure`)  
Remote: `origin https://github.com/mafaq2502-creator/Apps.git`

Latest handoff update: after the light-theme implementation pass, at the user's
request. This update changes documentation only; implementation changes remain
uncommitted. This root handoff is currently untracked and must be preserved.

## Read this first

This file is the entry point for a new Codex session. Work only in the D-drive
workspace above. A C-drive copy was used by an older session and is not the
source of truth.

The underlying task is to finish the **light-theme UI** against the saved master
reference while preserving existing Firebase, authentication, CRUD, validation,
and navigation behavior. A further implementation pass has added screens and
refinements, but the entire light-theme task is **not yet complete**. The earlier
completion message overstated the result: source review shows pending UI work,
static placeholders, and presentation behavior that needs repair below.

The latest user request is to update this existing handoff with completed and
remaining work. Do not interpret this documentation update as another completed
implementation batch.

Current constraints for subsequent work:

- **Do not run an emulator or build an APK.** The user explicitly excluded both.
- **Do not start Dark Theme.** It is a separate, deferred phase requiring a new
  user instruction.
- Keep implementation UI-only: preserve services, models, Firebase contracts,
  Functions, rules, dependencies, and Android/iOS configuration. Missing backend
  capabilities need honest unavailable/empty UI, not fabricated live data.
- Continue in this file; do not create another handoff or repeat a broad audit.

The two visual source-of-truth images are committed here:

- `docs/design-references/all-screens-light-theme.png`
- `docs/design-references/all-screens-dark-theme.png`

The word **SafeCircle** inside those images is a visual placeholder. The app has
not been approved for renaming. Preserve the current product name until the user
explicitly requests a rename.

Also read:

- `docs/PROJECT_HANDOFF.md` — earlier detailed implementation history.
- `docs/ALIVECIRCLE_IMPLEMENTATION.md` — target domain model and ordered phases.
- `docs/UI_COLOR_PALETTE.md` — approved light/dark color tokens.
- `docs/design-references/README.md` — reference-image rules.

Some statements in the older handoff describe an earlier code state. Prefer the
current source code and this file when they conflict.

## Product summary and confirmed decisions

Family Emergency is a consent-based family-safety Flutter application. Users
create or join Family Circles, manage members, perform a daily “I'm Alive”
check-in, and send SOS events to selected Circle recipients.

Confirmed product rules:

- Relationship labels such as Father, Mother, Son, and Daughter describe a
  person. They never grant authorization.
- Circle authorization uses only `circleRole`: `owner`, `parent`, `adult`, or
  `child`.
- An owner or parent can manage a Circle; only its owner can delete it.
- Emergency notifications go only to the selected Circle recipients.
- Location, battery, profile-photo, and notification sharing require the
  individual member's consent.
- Use “Device offline” or “Last seen,” not an unverified claim that a phone is
  switched off.
- Daily Check-in is a welfare reminder, not proof that somebody is unsafe.
- Free plan concept: Circle owner plus up to 2 invited members.
- Premium plan concept: Circle owner plus up to 10 invited members.
- Seats beyond 10 are intended to be billed per active member to the Circle
  owner. Removed or declined members should not consume seats.
- A subscription belongs to a Family Circle owner. Invited members do not each
  need to buy Premium to participate in that Premium Circle.
- Entitlements must eventually be enforced by a trusted backend, not by the
  client UI.

## Design system

The approved visual direction is calm, rounded, family-focused, and safety
oriented.

### Light theme

- Soft off-white page background.
- White rounded cards and fields.
- Navy headings and readable neutral body text.
- Emerald gradients or solid emerald for primary actions, selected items,
  success, online, and checked states.
- Red is reserved for SOS, urgent warnings, and destructive actions.
- Subtle background circles, shadows, and large rounded corners follow the
  master reference.

### Dark theme

- Navy-black background with dark navy/charcoal cards.
- White primary text and muted blue-grey secondary text.
- Emerald for normal selected/success/online states.
- Red only for emergency/destructive actions.
- Keep the same hierarchy and layout as light mode; change theme tokens and
  contrast rather than inventing a second structure.

### Navigation

The authenticated bottom navigation is:

1. Family (`_currentIndex == 0`)
2. Progress (`_currentIndex == 1`; the source file retains the legacy name
   `location_tab.dart`)
3. Home (`_currentIndex == 2`)
4. Plan (`_currentIndex == 3`)
5. Profile (`_currentIndex == 4`)

Home is selected by default. Its larger circular action is raised above a
custom curved/wave navigation surface.

## Technology and dependencies

- Flutter/Dart package with SDK constraint `^3.13.2`.
- Firebase Core `^4.14.0`.
- Firebase Authentication `^6.6.1`.
- Cloud Firestore `^6.9.0`.
- Cloud Functions client `^6.4.0`.
- Google Sign-In `^7.2.0`.
- Google Fonts `^6.3.3` (Manrope in the app theme).
- Country Picker `^2.0.28`.
- Flutter Timezone `^5.1.0`.
- Cupertino Icons `^1.0.8`.
- Firebase Functions use Node 20, TypeScript, `firebase-admin ^13.0.0`, and
  `firebase-functions ^6.0.0`.

There is currently no Firebase Storage, image-picker, Firebase Messaging,
local-notification, maps/location, payment, QR-scanner, device-health, or
screen-time dependency in `pubspec.yaml`.

## Application architecture

Bootstrap and routing:

- `lib/main.dart` initializes Firebase and runs `FamilyEmergencyApp`.
- `lib/app/family_emergency_app.dart` owns Material light/dark themes and uses
  `AuthGate` as the default home.
- `lib/core/theme/theme_mode_controller.dart` exposes the app-wide
  `ValueNotifier<ThemeMode>`; the initial value is System.
- `lib/features/auth/presentation/auth_gate.dart` listens to Firebase Auth,
  loads the Firestore profile, checks Circle membership, and deterministically
  routes to profile setup/recovery, Circle onboarding, or Home. Signed-out users
  now see the two-page `IntroFlow` before Login once per process. This added
  presentation route is not persistent onboarding state; see remaining work.

Authenticated shell:

- `lib/features/shell/presentation/family_shell.dart` is still the main stateful
  controller for the five tabs. It owns selected Circle state, member streams,
  profile edit state, check-in state, SOS countdown, and navigation callbacks.
- The tab UIs are `part` files under
  `lib/features/shell/presentation/tabs/`: `home_tab.dart`,
  `members_tab.dart`, `location_tab.dart`, `plan_tab.dart`, and
  `profile_tab.dart`.
- Several older duplicate widget implementations remain later in
  `family_shell.dart`. Treat this file carefully and verify which extension or
  method is used before editing. Do not perform a broad cleanup during the
  UI-only task.

Separation already present:

- `lib/models/` contains Firestore/domain models.
- `lib/services/` contains Firebase Auth, Firestore, Cloud Functions, profile,
  Circle, member, notification, and emergency boundaries.
- `lib/core/widgets/` contains reusable brand, background, field, button, card,
  and surface widgets. The latest `light_ui.dart` adds shared page, card,
  section-title, status, avatar, settings-row, toggle, and state widgets.
- Feature-level screens live under `lib/features/`.

## Authentication and onboarding status

Implemented in the client:

- Firebase Auth session stream and deterministic startup routing.
- Email/password login and signup.
- Google authentication client flow.
- Apple authentication client flow.
- Password-reset email screen/action.
- Provider-profile creation and missing-profile recovery.
- Full name, normalized email, country-aware phone, relationship, and password
  validation.
- Email signup updates Firebase Auth display name and creates `users/{uid}`.
- Create Circle and Join Circle onboarding tabs.
- Join Circle calls the callable `redeemCircleInvite` function.
- Duplicate-submit guards and mapped Firebase Auth errors.
- New `StartupSplash` replaces the AuthGate session/profile waiting screens;
  the earlier Firebase initialization screen in `main.dart` is still separate.
- New `IntroFlow` adds two introductory pages with navigation and indicators.
  `_introSeenThisRun` is static in-memory state, so a new signed-out app process
  repeats the introduction. Do not describe it as persisted first-run behavior.

External configuration still required:

- Google and Apple providers must be enabled/configured for every target
  platform in Firebase Console. Apple also needs Apple Developer/Xcode
  entitlements.
- Callable Circle invitation functions must be deployed. The earlier session
  recorded a Blaze-plan blocker for the Firebase project
  `familyemergencyapp`.

## Current screen and feature status

### Authentication screens

- Login, Sign Up, Forgot Password, Profile Setup/Recovery, and Circle
  Onboarding retain their earlier light-theme foundation. They were not all
  reworked or visually verified in the latest batch.
- Added `lib/features/auth/presentation/onboarding/intro_flow.dart`, containing
  two intro pages and `StartupSplash`; a compact-height intro overflow was fixed.
- Remaining: final reference artwork, wordmark/tagline and splash composition,
  consistency with initial Firebase loading/error UI, and review of intro route
  behavior against the requirement to preserve onboarding/auth navigation.
- Country pickers and relationship selectors retain their existing separate
  implementations; a consistent reusable picker/modal treatment is still pending.

### Home

- Opens at bottom-nav index 2.
- Shows greeting/profile name, notification bell, Circle cards, selected group
  navigation, “I'm Alive,” and Emergency controls.
- Added SOS confirmation before the existing 3-second countdown and Firestore
  emergency creation. The existing check-in persistence remains connected.
- Persists the latest daily check-in timestamp, time zone, and local date in the
  user's profile document.
- Empty Home keeps check-in and Emergency controls in the lower action area.
- Remaining: reference spacing, illustrations/avatars, empty/populated/action
  states, and compact/large-text layout verification of the authenticated shell.

### Family / Circles / Members

- Live Circle query, Circle creation, selection, rename, owner deletion, and
  emergency-recipient editing are implemented.
- The Home/Family UI updates optimistically after Circle creation and retries a
  failed Circle watcher.
- Added Owned/Joined Circle filtering and cards in `tabs/members_tab.dart`.
  `group_members_screen.dart` now includes Circle summary and settings/invite
  navigation alongside its existing member list.
- Group-member CRUD still uses `groups/{circleId}/members`. The light-styled
  Add Member dialog creates a manual compatibility member, not a registered-user
  email/role invitation. Do not conflate it with callable invite-code redemption.
- `group_settings_screen.dart` gained rename/delete confirmations and Share
  Circle navigation while retaining recipient editing. Leave Circle and Transfer
  Ownership only show unavailable messages; they do not perform those operations.
- `member_profile_screen.dart` gained device/pairing/progress navigation.
  Member notification settings/editor received light styling and retain saving.
- Remaining: full Circle Detail/Members hierarchy and summaries, Circle member
  counts, registered-user Add/Invite presentation, member device/progress summary
  layout, and final settings/notification preference layouts.
- Existing Family member cards still substitute sample phone numbers and always
  show a green status dot. Replace missing-data fallbacks with truthful states;
  verify long names/phone/relation text in the fixed-height cards.
- Added Circle rename/delete calls need pending/error feedback and navigation
  review after deletion. Settings displays an owner UID instead of a readable
  identity. The older Group Members delete menu uses `canManage`; align its UI
  availability with the existing owner-only delete rule without changing rules.

### Share Circle

- Added `lib/features/groups/presentation/share_circle_screen.dart`.
- Generates a real invitation code/expiry via the existing
  `CircleJoinService.createInvite` and copies the code to the clipboard.
- QR/Code/Link tabs are visual only. The QR image is a Material icon, not an
  encoding of the invitation. It is not scannable.
- Joining links are explicitly unconfigured and their copy control is disabled.
  “Copy Invitation Code” copies text; it is not an operating-system share sheet.
- Remaining: functional presentation tab selection, consistent generation/busy
  states, and either real local rendering of the existing invite code as QR or
  an explicit unavailable QR state. Do not invent a deep link or new invite backend.

### Progress

- The old Location tab has been repurposed as Progress in navigation and UI
  language; the source filename remains `location_tab.dart`.
- The target product removed the standalone Live Location/map screen.
- Added `ProgressDetailsScreen`, `ScreenTimeDetailScreen`, and
  `CheckInHistoryScreen` in `progress_detail_screens.dart`, with navigation from
  Progress/member screens. These are presentation screens, not telemetry flows.
- The overview Circle selector works; member and Today/Week/Month controls remain
  static. Yesterday is missing and the overview settings action is a no-op.
- Screen Time uses fixed totals, chart bars, and app usage. Check-In History uses
  hardcoded checked/missed entries rather than persisted history. Overview device
  metrics are also sample values. These values are not clearly labeled as samples.
- Remaining: replace fabricated readings/history with honest no-data states or
  existing available data, implement presentation filter selection and reference
  layouts, and distinguish the real latest check-in from unavailable history.
  Building telemetry/history storage is outside this UI task.

### Devices

- Added `DevicePairingScreen` and `DeviceDetailScreen` in
  `lib/features/devices/presentation/device_screens.dart`.
- Pairing shows Circle/member context, QR icon, code input, consent, and a button
  that reports pairing is not connected. It does not scan, validate, or pair.
- Device Detail currently substitutes `iPhone 13`, 78% battery, and 45% storage
  when no device data exists. A non-null device is labeled online without checking
  freshness, and its enabled Unpair button does nothing.
- Remaining: truthful not-paired/offline/unknown/consent states, no fabricated
  metrics, disabled/explained unsupported actions, and final reference layout.
  Pairing/unpairing services and real device telemetry remain separate work.

### Plan

- Free/Premium cards now state owner plus 2 / owner plus 10 invited members.
  Feature copy was adjusted, including Premium battery alerts.
- Upgrade and subscription management remain unavailable-message actions;
  displayed pricing is illustrative, not a configured purchasing contract.
- Pricing, checkout, subscriptions, seat counting, extra-seat billing, restore
  purchase, and backend entitlement enforcement are not implemented.
- Remaining: reference plan-selection layout and responsive scrolling. The
  current two-column cards use a constrained Column/Spacer layout and are not
  covered by the new compact-screen tests; small-height/large-text overflow is
  still a risk.

### Profile and settings

- Profile now opens a new `account_settings_screen.dart` for name/relationship
  edits, with read-only email/phone, a country placeholder, and password entry.
- The save callback still writes Firestore and synchronizes the Firebase Auth
  display name. However, the new stateless route captures `saving` and relationship
  from the shell, does not require dirty state to enable Save, and has no local
  unsaved-exit guard. The shell's existing guard does not guard this child route.
  Restore reactive saving/validation and Save/Discard/Keep Editing behavior here
  before claiming existing edit behavior is preserved.
- Remaining hub navigation: Current Plan has no action, Circle Settings is absent,
  and Account Settings “Update Password” opens the security settings hub rather
  than the password screen directly. Country is not populated from profile data.
- Theme selector is a single-row `System | Light | Dark` control with one
  emerald selection.
- Personal/global notification settings persist in the user profile.
- Logout now has confirmation before the existing sign-out callback.
- Profile Settings, password UI, and the three-step Delete Account UI were
  retained rather than completed in this batch. Final layout/modal/state styling
  remains; existing security flows include demo behavior and are not production
  account operations.
- Profile photo upload/replace/remove is not implemented; there is no picker or
  Storage package.
- Firebase reauthentication, actual secure password updates/account deletion,
  and photo upload remain separate functionality tasks. Style their unavailable
  states honestly in the light UI.

### Notifications and emergencies

- Notification bell keeps its top banner and now provides View All navigation.
  The center gained All/Unread and Circle filtering while retaining the live
  notification stream and mark-one/mark-all-read calls.
- Emergency history gained Active/Acknowledged/Resolved filters and navigation
  to the new `emergency_detail_screen.dart`. Existing acknowledge/resolve service
  calls remain connected.
- Emergency Detail shows sender, Circle and available event time; location and
  battery are unavailable. Call only shows a message. “Open Member Profile”
  currently just pops the route. Acknowledge uses a static event snapshot without
  local pending/error/refreshed-success presentation.
- Remaining: correct member navigation or explicit unavailable state, accurate
  emergency status presentation, action feedback, and final banner/history/detail
  styling. Verify View All navigation after closing the banner.
- The notification model does not expose a timestamp or emergency identifier for
  detail navigation. Do not invent timestamps/links. Loading, error/retry, per-type
  presentation, and banner sizing still need a full state pass; center/history
  error states do not currently wire a Retry action.
- Functions create in-app Firestore notifications for an emergency and its
  acknowledgement.
- FCM token registration, push delivery, local notification display, SMS/call
  fallback, background processing, and missed-check-in scheduling are not
  implemented.

## Firebase data model

### `users/{uid}`

Current profile fields used by the app include:

```text
uid
name
email
phone
phoneCountryIso
phoneCountryCode
relationship
photoUrl
providerIds[]
profileCompleted
onboardingCompleted
notificationSettings
lastSignInAt
lastDailyCheckInAt
lastDailyCheckInTimeZone
lastDailyCheckInLocalDate
createdAt
updatedAt
```

Subcollections:

- `users/{uid}/notifications/{notificationId}` — server-created in-app
  notifications. The client may only update read state under deployed rules.
- `users/{uid}/checkIns/{localDate}` — target structure exists in rules, though
  the current client primarily records the latest check-in fields on the user
  document.
- `users/{uid}/members/{memberId}` — legacy owner-scoped member service remains
  in code. The active shell uses Circle members instead.

### `groups/{circleId}`

Circle fields:

```text
name
ownerId
memberIds[]
roles.{uid}
emergencyRecipientIds[]
createdAt
updatedAt
```

`memberIds` and `roles` are an authorization/query cache during migration. They
must remain consistent with membership documents through atomic trusted writes.

Subcollections and purpose:

- `memberships/{uid}` — registered users, display data, `circleRole`, status,
  and join timestamps. This is the target detailed member record.
- `members/{memberId}` — temporary compatibility collection used by current
  manual member CRUD. Remove only after the registered-user invitation flow is
  fully live.
- `invites/{inviteId}` — invitation code, role, expiry, status, and usage.
- `devices/{deviceId}` — target pairing/health model.
- `progressDaily/{uid_localDate}` — target daily progress aggregates.
- `locationEvents/{eventId}` — future opt-in location activity.
- `emergencies/{emergencyId}` — SOS status, sender, acknowledgement, and
  resolution fields.

### `inviteLookup/{code}`

Server-only lookup used by callable invite redemption. Direct client reads and
writes are denied by Firestore rules.

### Indexes

`firestore.indexes.json` defines compound indexes for:

- `progressDaily`: `userId ASC`, `localDate DESC`.
- `locationEvents`: `userId ASC`, `occurredAt DESC`.

## Firebase Functions

`functions/src/index.ts` implements:

- `sendEmergencyToRecipients` — Firestore create trigger that writes in-app
  notifications for configured Circle recipients other than the sender.
- `notifyEmergencyAcknowledgement` — Firestore update trigger that notifies the
  SOS sender when another member acknowledges it.
- `createCircleInvite` — authenticated callable; owner/parent creates a
  10-character code with seven-day expiry and a usage limit.
- `redeemCircleInvite` — authenticated callable; validates code, rejects
  expired/exhausted/duplicate membership, atomically updates `memberIds`,
  `roles`, `memberships/{uid}`, invite usage, and onboarding state.

FCM is intentionally left as a comment. These functions currently create
Firestore notifications only.

## Firestore security rules

The checked-in `firestore.rules` enforce these important boundaries:

- Users can create/read/update only their own profile; direct profile deletion
  is denied.
- Notification creation/deletion is server-only; clients can update read state.
- Circle reads require membership.
- Circle creation requires the authenticated user to be the sole initial owner,
  member, and emergency recipient.
- Circle updates are limited to approved fields and Circle managers.
- Circle deletion is owner-only.
- Memberships, invites, devices, progress, location events, and emergencies have
  scoped member/manager/owner rules.
- Invite redemption is deliberately delegated to a trusted Cloud Function.

Deployment is an external manual step. Do not assume the repository rules or
indexes are live in Firebase merely because they exist locally.

## Implemented baseline and latest UI pass

- Baseline Flutter project and Firebase bootstrap.
- Shared theme tokens and reusable UI components.
- Circle roles, memberships, invites, paired-device models, indexes, and
  compatibility strategy.
- Firestore rules and local rules test suite.
- Auth routing, email/Google/Apple client paths, password reset, profile
  recovery/completion, and Create/Join Circle onboarding.
- Circle create/read/rename/delete and current manual member CRUD.
- Firestore SOS events, acknowledgement/resolution, and server-written in-app
  emergency notifications.
- Daily check-in client persistence.
- First light-theme pass across authentication, onboarding, main tabs, and
  several nested screens.
- Master light and dark design references saved in the repository.
- Latest light-theme additions: shared light UI widgets; startup/intro screens;
  Account Settings; Share Circle; emergency detail; progress, screen-time and
  check-in detail; device pairing/detail presentation; Circle scope filters;
  notification/emergency filters; and SOS/logout confirmations.
- Three new responsive widget tests and the compact intro overflow fix.

New files in the latest implementation pass:

- `lib/core/widgets/light_ui.dart`
- `lib/features/auth/presentation/onboarding/intro_flow.dart`
- `lib/features/devices/presentation/device_screens.dart`
- `lib/features/groups/presentation/emergency_detail_screen.dart`
- `lib/features/groups/presentation/share_circle_screen.dart`
- `lib/features/profile/presentation/account_settings_screen.dart`
- `lib/features/progress/presentation/progress_detail_screens.dart`
- `test/light_theme_responsiveness_test.dart`

Existing files changed in that pass:

- `lib/features/auth/presentation/auth_gate.dart`
- `lib/features/groups/presentation/emergency_events_screen.dart`
- `lib/features/groups/presentation/group_members_screen.dart`
- `lib/features/groups/presentation/group_settings_screen.dart`
- `lib/features/members/presentation/member_notification_settings_editor.dart`
- `lib/features/members/presentation/member_notification_settings_screen.dart`
- `lib/features/members/presentation/member_profile_screen.dart`
- `lib/features/notifications/presentation/notification_banner.dart`
- `lib/features/notifications/presentation/notification_center_screen.dart`
- `lib/features/shell/presentation/family_shell.dart`
- `lib/features/shell/presentation/tabs/location_tab.dart`
- `lib/features/shell/presentation/tabs/members_tab.dart`
- `lib/features/shell/presentation/tabs/plan_tab.dart`
- `lib/features/shell/presentation/tabs/profile_tab.dart`

Services, models, Functions, Firestore rules/indexes, Firebase/platform config,
dependencies, and existing tests were not edited in that pass. This does not prove
all behavior was preserved: the new profile route, introduction, and detail-screen
actions have the presentation gaps described above. All listed changes are local;
no commit, push, build, or deployment is recorded for this pass.

## Verification from the last implementation run

- `flutter analyze --no-pub`: **No issues found** (10.2 seconds).
- `flutter test --no-pub`: **33 tests passed** (the earlier 30 plus 3 new tests).
- Dart formatting was run on the changed files. `git diff --check` reported no
  whitespace errors; an informational LF/CRLF warning was seen for AuthGate.
- The new tests check Intro navigation and initial render/layout exceptions for
  Screen Time, Check-In History, Device Detail, and Pair Device at **320 x 568**
  and **430 x 932**. Account Settings is checked at **320 x 568**. Long member
  names and long account details are included.
- Those tests do **not** establish visual parity, validate real Firebase flows,
  test profile save/back behavior, or cover every authenticated tab/modal. No
  golden screenshots, keyboard/large-text pass, or full screen/state matrix was
  completed. A clean analyzer/test run is not evidence that every UI is finished.
- **No emulator was launched and no APK was built.** Both remain excluded by the
  user's instruction. New output screens were not visually inspected in this pass.
- Functions builds, rules tests, and deployed Firebase state were not freshly
  verified in the UI pass.
- These are results from the preceding implementation turn, not a fresh test run
  during this documentation-only update.

## Active task: finish light-theme UI only

Status: **implementation pass completed; full light-theme scope still open**.
The following items remain from the current task. They are UI work, not permission
to implement missing backend features. Detailed evidence is in the screen-status
sections above.

1. **Restore edit behavior:** make Account Settings react to saving/dirty/error
   state and preserve unsaved-exit confirmation on the actual editing route.
   Verify name/relationship saving and locked identity fields using existing
   callbacks. Populate available country information and correct settings links.
2. **Remove misleading data/actions:** replace hardcoded device, progress,
   check-in-history, phone, and online values with existing real data or explicit
   no-data states. Correct Emergency Detail's member action and unsupported
   Pair/Unpair/Call controls. Add pending/error/success feedback to connected
   emergency and Circle actions without changing services.
3. **Finish selectors and sharing presentation:** make the intended Progress
   member/period filters and Share Circle tabs behave consistently; include the
   reference's Yesterday state where applicable. Complete real-code QR rendering
   or visibly mark it unavailable. Keep unconfigured invite links unavailable.
4. **Complete Circle/member hierarchy:** refine Owned/Joined listing, full Circle
   Detail, member counts/list, Add/Invite Member, Circle Settings, Member Detail
   device/progress summaries, and Member Notification Settings. Preserve manual
   member CRUD and callable invitations as their existing separate flows.
5. **Complete remaining reference layouts:** splash/intro artwork and branding;
   authentication/onboarding refinements; Home and bottom navigation; notification
   banner/center; emergency detail/history; Progress details; Profile hub/Account
   Settings/Profile Settings; and Plan selection/scrolling.
6. **Finish modal and state frames:** SOS, logout, delete-account steps, country
   picker, relationship/role selectors, and Save/Discard/Keep Editing. Check
   validation, loading, success, empty, disabled, error, and wired retry states.
   Retained legacy dialogs are not evidence of final reference completion.
7. **Complete visual and responsive verification:** compare every required screen
   and state with the light reference using widget renders/screenshots without
   launching an emulator or building an APK. Check short/tall phones, long text,
   large text scale, keyboard insets, scrolling, safe areas, and action feedback.
   Existing tests cover only the subset listed above.

The approved design plan contains 28 actual navigable screens plus modal/state
frames. A count of Dart files or added routes is not a coverage checklist. Map the
remaining screens to the reference before declaring parity, retaining existing
working routes and documenting unavailable features. Dark Theme is deferred and
is not part of the remaining light-theme checklist.

## Known issues and risks

- The current UI is not fully reference-verified, and the passing test subset
  does not cover the behavior gaps listed above.
- New shared light widgets use explicit light colors. The existing theme selector
  remains, but cross-theme appearance has not been verified. Do not claim Dark
  Theme completion or begin a dark redesign during this phase.
- Flutter initially stalled or reported access-denied errors under the sandbox;
  analyzer/tests later succeeded with approved access to the Flutter SDK/Pub
  cache. If this recurs, use the normal sandbox approval mechanism. Temporary
  `.dart_appdata` and `.dart_localappdata` workaround folders were removed.
- An earlier shell did not have `npm` on PATH; Functions verification was not
  repeated in this UI task. Resolve runtime availability only for separately
  requested backend verification.
- The older Pixel_7 AVD crash note remains historical and unverified. Emulator
  troubleshooting is outside the user's current request; do not launch it.
- Firebase rules, indexes, and Functions may not be deployed. Repository state
  and deployed backend state can differ.
- Firestore enablement was an earlier blocker. Verify the current Firebase
  Console/project state before diagnosing client persistence.
- The current member system has two shapes: target registered-user
  `memberships` and temporary manual `members`. Do not silently merge or delete
  either during UI work.
- `GroupService.deleteGroup` removes only `members` and `emergencies` before the
  group document; other target subcollections need a trusted recursive cleanup
  design before production deletion.
- `FamilyMemberService.watchGroupMembers` errors are swallowed by the shell,
  while group watcher errors show a retry message.
- Profile photo, real device telemetry, push notifications, scheduled missed
  check-ins, location services, payments, and entitlement enforcement remain
  unimplemented.
- Account deletion, password history, and secure verification require backend
  work and reauthentication; UI alone must not be presented as complete
  security behavior.
- The repo is on `main` and the remote points to a broader repository named
  `Apps`. Inspect remote layout before pushing or opening a PR.

## Exact next steps for a fresh session

1. Confirm the workspace is exactly `D:\My Projects\family_emergency_app` and
   run `git status --short`. Preserve the listed local changes and this untracked
   handoff. Do not rebuild the app from scratch or repeat a broad repository audit.
2. Use the latest user instruction to distinguish a handoff/status request from
   resumed implementation. This handoff-update turn changed only this document.
3. When implementation resumes, read the relevant source and light-reference
   panels. Start with Account Settings save/back behavior, misleading sample data,
   and broken/no-op detail actions; then work through the remaining checklist.
4. Reuse the established components and callbacks. Keep services, models,
   Firebase paths, validation rules, dependencies, and platform config unchanged.
   Do not add telemetry, pairing, payments, push, or security backends for UI parity.
5. Add focused behavior tests for repaired navigation/save interactions as needed.
   Use widget rendering for visual checks; **do not launch an emulator, run the app
   on an emulator, or build an APK** under the current instruction.
6. Format changed Dart files, run the analyzer and relevant tests, then the full
   Flutter suite at completion. Do not rerun application tests for handoff-only
   wording changes. Do not deploy anything as part of the UI task.
7. Update this same file with actual changes, verification evidence, and remaining
   gaps. Do not equate the analyzer/test result with visual or functional parity.
8. Stop at the light-theme scope. Dark Theme remains deferred until the user
   explicitly starts that phase.

## Development and verification commands

For a resumed UI implementation, run from the project root in PowerShell. The
Flutter executable previously used on this machine is explicit below because
`flutter` may not be on PATH. No emulator or APK commands are included because the
user excluded them. These commands are not required for this handoff-only update.

```powershell
Set-Location -LiteralPath 'D:\My Projects\family_emergency_app'

C:\Users\Farhan\develop\flutter\bin\flutter.bat analyze --no-pub
C:\Users\Farhan\develop\flutter\bin\flutter.bat test --no-pub
```

Run the latest responsive tests while iterating:

```powershell
C:\Users\Farhan\develop\flutter\bin\flutter.bat test --no-pub test\light_theme_responsiveness_test.dart
```

Run `dart.bat format` with only the Dart files changed in the resumed batch.
Dependencies are already resolved for the recorded run; use `pub get` only if
resolution is actually needed. Backend builds, rules-emulator tests, and Firebase
deployment are separate from this UI work and were not performed in the last pass.

## Definition of done for the current UI task

- Existing Firebase contracts are unchanged, and presentation interactions still
  preserve working save, validation, navigation, and unsaved-edit behavior.
- All existing navigable screens and relevant modal/state frames match the
  light master reference in layout, hierarchy, typography, colors, spacing,
  radii, shadows, and icons as closely as available assets allow.
- Missing external assets use an intentional, consistent placeholder and are
  documented.
- Unsupported capabilities are visibly unavailable. No hardcoded readings,
  check-in events, contact details, online status, or QR icons masquerade as real
  member/device/invitation data.
- UI works at phone widths without overflow or clipped controls.
- System/Light/Dark selector remains single-choice and defaults to System on a
  fresh launch.
- Emerald remains the normal action/selection color; red remains reserved for
  emergency/destructive use.
- Formatting, analyzer, and tests pass.
- Screens and modal/state frames are visually inspected against the reference
  through widget renders/screenshots within the user's no-emulator/no-APK
  constraint. Any unverified coverage is explicitly reported.
- This definition is not yet met; the current remaining checklist stays open.
