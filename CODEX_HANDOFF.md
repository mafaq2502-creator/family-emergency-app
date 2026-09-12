# Family Emergency App — Codex Handoff

## Phone, onboarding, navigation, and shared-control follow-up (2026-09-13)

Status: **SOURCE COMPLETE, LOCAL VERIFICATION PASSES, AND APK BUILT.**

- Circle onboarding is now Join-only. Create Circle remains available from the
  Family flow, and a user may continue without joining a Circle.
- Mobile number entry is shared by Sign Up, profile onboarding, and Account
  Settings. It supports a searchable country-code picker, manual override,
  paste normalization, E.164 storage, and validation against duplicated codes,
  letters, malformed plus signs, and invalid lengths. Failed Account Settings
  saves retain the entered value and report the error.
- Relationship moved from Sign Up to profile onboarding. Provider users with an
  incomplete profile are sent through the same required country, phone, and
  relationship step. A profile cannot be marked complete without these fields.
- Login/Sign Up cross-links are simple emerald text. Email verification Cancel
  stops pending timers/checks and signs out on the first tap, with repeated taps
  safely ignored.
- Bottom navigation is ordered Progress, Family, Home, Plan, Profile while
  preserving the existing destination indices. Non-Home items sit 2dp lower;
  the green painter stroke is limited to the top wave, with no green side or
  bottom border.
- Global switch theming keeps off and disabled tracks/thumbs visible in dark
  mode. Shared dialogs use equal-width two-action rows and centered single
  actions; their close control discards unsaved input.
- Firestore profile rules accept an empty legacy phone only while a profile is
  incomplete. Completed profiles require a canonical E.164 number, ISO country,
  and calling code.
- Verification: 305/305 Flutter tests pass; `flutter analyze --no-pub` reports
  no issues; 20/20 Firestore emulator test cases pass; and `git diff --check`
  reports no whitespace errors (only line-ending warnings).
- After a separate explicit request, a standard release APK was created without
  the email-verification testing override:
  `build/app/outputs/flutter-apk/app-release.apk`, 76,509,162 bytes (72.96 MiB),
  SHA-256 `5AE81043F4A489DCDC80CA0E98198BCD7272982D25F9832BA77C68C2F442BEF7`.
  APK Signature Scheme v2 verification passed with one Android debug signer.
  Future builds still require a separate user request.

## SOS, Free Plan limits, single-use invitations, and deletion authority (2026-09-13)

Status: **SOURCE COMPLETE AND LOCAL TESTS PASS. PRODUCTION DEPLOYMENT PENDING.**
This section supersedes the older Spark/client-deletion notes below.

- Circle create, invite, join approval/rejection/cancellation, member removal,
  leaving, and owner deletion now use trusted callable transactions. Direct
  client entitlement and lifecycle mutations are denied by Firestore rules.
- Owner deletion is authorized from the group document, then atomically
  tombstones the Circle and cleans memberships, profile references, invites,
  pending requests, Circle device links, and Circle notifications. The UI waits
  for the callable result, so an optimistic removal cannot reappear one second
  later with a permission error.
- Free accounts may own one active Circle and join one additional Circle. A Free
  Circle holds three active people total (owner plus two); active unexpired
  single-use invitations reserve the remaining slots. Approval rechecks both
  user entitlement and Circle capacity in the transaction.
- Invitation links and QR codes share one 24-character token. States are active,
  consumed, expired, and revoked. Approval consumes a token; revocation,
  cancellation, and rejection release its slot. Replay is rejected.
- SOS now uses a cancellable 5-to-1 countdown and validates stored recipients
  against current active Circle members. The sender is excluded. FCM and
  notification history use that exact recipient list.
- Root title/bell placement, the five-item curved navigation bar, Home/SOS
  placement, Plan copy and pricing, premium feature gates, capacity UI, and
  close-without-save controls on dialogs/sheets are implemented.
- Verification: 299/299 Flutter tests passed; `flutter analyze --no-pub` reports
  no issues; 34/34 Firestore/device/trusted-boundary rule tests pass; 10/10
  callable integration tests pass; Functions TypeScript passes `tsc --noEmit`;
  and `git diff --check` has no whitespace errors (only line-ending warnings).
- Per the user's standing instruction, no APK, release bundle, or app build was
  produced in this task. Do not build until the user explicitly requests it in
  a separate prompt.
- To activate this behavior for production users, deploy `functions`,
  `firestore.rules`, and `firestore.indexes.json` together. The repository has
  not been deployed in this task.

## Global UI consistency follow-up (2026-09-13)

Status: **IMPLEMENTED, VISUALLY INSPECTED, AND AUTOMATED TESTS PASS.**

- Standardized every Material field label through the shared theme at 15sp,
  semibold, 1.2 line height. Light, dark, and System themes inherit the same
  hierarchy while hints, values, helpers, and errors retain their distinct sizes.
- Standardized AppBar screen-title placement through the shared theme: 64dp
  toolbar height, 16dp title spacing, left alignment. `LightPage` subtitles now
  sit below the AppBar so page titles share the same vertical placement. Home
  now uses `Home` as its AppBar title and keeps its personalized greeting in the
  page content.
- Rebuilt bottom navigation from the supplied reference: Family, Progress,
  raised circular Home, Plan, Profile; curved accent edge, theme-aware surface,
  glow, consistent label baseline, and preserved destination indices/tap logic.
- Replaced all 18 app AlertDialogs with a shared closeable dialog. The cross
  returns no result, so unsaved field edits are discarded. The member-edit
  bottom sheet and existing notification popup also expose the same close action.
- Added regression checks for field-label typography in both themes, common
  AppBar geometry, unsaved-dialog cancellation, navigation order/raised Home,
  320px layout, 1.5 text scale, and 0/24/48dp system insets.
- Verification: all 294 Flutter tests pass; responsive/theme matrix passes;
  `flutter analyze --no-pub` reports no issues. Light/dark form renders and the
  bottom-navigation render were visually inspected.
- Rebuilt testing APK with `AUTO_VERIFY_EMAIL_FOR_TESTING=true`:
  `build/app/outputs/flutter-apk/app-release.apk`, 76,574,822 bytes (73.03 MiB),
  SHA-256 `874B1BDBBB05A4081B5559A293C2F321EA1FE94CAA0927FF872EC7FC218FFABC`.
  APK Signature Scheme v2 verification passed with one Android debug signer.

## Circle deletion rollback follow-up (2026-09-13)

Status: **FIXED LOCALLY AND VERIFIED. Production requires the updated complete
`firestore.rules` plus the rebuilt app.**

- Reproduced the reported sequence: Firestore's optimistic local batch removed
  the Circle from the query, then a rules rejection rolled the batch back and
  made the Circle reappear with a permission error.
- The owner profile cleanup was being checked by the general profile validator.
  A valid older profile containing legacy fields could therefore reject the
  complete atomic deletion even though `ownerId` and the Circle role were valid.
- Added a narrowly scoped profile cleanup rule. It permits only removal of the
  deleted Circle reference and selected-Circle cleanup, and only in the same
  atomic write as a valid owner Circle tombstone. It cannot edit unrelated
  profile fields or remove another Circle reference.
- Moved Circle-device deletion cleanup ahead of costly alternative rule checks
  to avoid Firestore's rule-expression limit on that atomic path.
- Group-list snapshots now ignore local pending writes, and Circle Detail shows
  a deletion progress state until Firestore confirms the commit. A rejected
  write no longer looks successful for a second before rolling back.
- Regression tests cover legacy owner profiles, both selected and non-selected
  Circles, standalone cleanup denial, unrelated profile-edit denial, wrong
  Circle removal denial, and the existing non-owner deletion denial.
- Verification: all 42 Firestore/invite/device rule tests pass, all 291 Flutter
  tests pass (including 14 focused Circle lifecycle tests), `flutter analyze`
  reports no issues, and `git diff --check` reports no whitespace errors.
- Rebuilt testing APK with `AUTO_VERIFY_EMAIL_FOR_TESTING=true`:
  `build/app/outputs/flutter-apk/app-release.apk`, 76,558,294 bytes (73.01 MiB),
  SHA-256 `D4D1310CBEE2B49019144ECB765FA5E1E91FC95B35D2B258A8A995587D345123`.
  APK Signature Scheme v2 verification passed with one Android debug signer.

## Email verification and Google Sign-In follow-up (2026-09-12)

- Email verification now observes Firebase `userChanges()`, reloads verification
  automatically every five seconds while the gate is visible, rechecks on app
  resume, and advances once Firebase reports `emailVerified=true`.
- Production **Next** is tappable and performs a real Firebase check instead of
  looking permanently disabled. It does not bypass verification.
- No Firestore `emailVerified` boolean was added; Firebase Authentication remains
  the single source of truth.
- Current `android/app/google-services.json` has no OAuth client entries. Google
  provider/support-email configuration alone is insufficient. Exact current
  debug signing SHA-1/SHA-256 and replacement steps are recorded in
  `docs/FIREBASE_AUTH_SETUP.md`.

## Resumed Account A task — Circle deletion, navigation, push/device permissions (2026-09-12)

Status: **SOURCE IMPLEMENTED, AUTOMATED TESTS PASS, AND ANDROID APK BUILT.
Production rules deployment and physical-device acceptance remain pending.**
Do not call this fully runtime verified. This section supersedes older notes for
these four fixes. The original 23-section prompt was read from the previous task's
attachment `5f59dac3-1364-4357-8604-faf6f49cdb8d/pasted-text.txt`. Account A stopped
at its usage limit while finishing cleanup and verification. Existing local work
was inspected and preserved, then corrected rather than restarted.

### 1. Status and scope

- Complete locally: Spark-compatible Circle deletion, shared bottom navigation,
  Android permission/settings/channels, device metadata/token lifecycle,
  notification destinations and route-layer predictive-back separation.
- No production user/Circle data was deleted during this task.
- No paid Firebase feature, Functions deployment, commit or push was performed.
- A rules-only production deployment was attempted after final verification, but
  automatic approval review rejected it pending fresh explicit approval for the
  exact `familyemergencyapp` production access-control change. It was not bypassed.
- No physical Android device was attached according to `adb devices -l`.

### 2. Principal modified files

- `lib/services/group_service.dart`, `profile_service.dart`, `auth_service.dart`,
  `push_notification_service.dart`, `device_service.dart`.
- `lib/app/notification_navigation.dart`, `family_emergency_app.dart`, `lib/main.dart`.
- `lib/core/domain/push_policy.dart`, `circle_error_mapper.dart`,
  `lib/core/theme/app_page_transitions.dart`, `lib/core/widgets/app_bottom_navigation.dart`.
- Family shell, notification settings/center and device detail presentation.
- Notification/device models, `firestore.rules`, `functions/src/index.ts`,
  Android manifest and native notification status/settings bridge.
- Package lock/declarations and generated platform plugin registration.
- `test/task_stabilization_test.dart`, existing lifecycle/theme/responsive tests,
  `rules-tests/firestore.rules.test.cjs`, `device.rules.test.cjs`, and this handoff.

### 3. Delete Circle root cause

The UI called `deleteCircle`, a Cloud Function that was intentionally undeployed
because the project remains on Spark. A functioning dialog did not imply a
working production backend. The unfinished fallback also left pending invites,
join requests and Circle device associations active.

### 4. Delete fix, data ownership and navigation

- Default Spark path uses the existing GroupService with a rules-protected atomic
  batch. A future configured Functions deployment can opt in with
  `USE_CIRCLE_LIFECYCLE_FUNCTIONS=true`; the callable source is retained.
- Only the actual owner can tombstone the Circle. Rules validate owner identity,
  timestamps, cleared role/member/recipient caches and allowed changed fields.
- Batch deactivates memberships, revokes invites, rejects pending requests,
  unpairs Circle-specific device associations, removes the owner's private
  notifications for that Circle and clears the owner's selected Circle/profile
  reference. No success is returned before the batch commits.
- Existing soft-delete/tombstone retention is preserved. Historical child records
  remain stored but Circle access rules revoke reads; they are not a physical
  recursive purge. Global users, installations and their private usage are retained.
- Private profiles belonging to other members are not exposed to the owner.
  Their stale references reconcile on their next successful server-backed profile
  load; live Circle queries remove the deleted Circle immediately. Pending users
  can read their rejected request and leave the pending flow.
- The future callable transaction also handles requester profiles, invites and
  Circle device links, and Circle-specific notifications for every affected user.
  Large cleanups exceeding the conservative 450-write limit stop without
  mutations and require a future server cleanup job.
- Existing confirmation/cancel, in-flight guard, failure/retry and route-result
  behavior are retained. Successful delete returns to Family; selected member
  filters are cleared when their Circle disappears. Failure stays on Circle Detail.

### 5. Bottom navigation

All five tabs now share AppBottomNavigation: 28dp icons in equal 48x44 slots,
3dp icon/label gap, shared label baseline and stable selected/unselected geometry.
Home follows the same geometry as the other destinations. Labels use a common
responsive scale rather than independently shrinking each word. SafeArea keeps
gesture/three-button insets below the controls. Both themes, all selections,
320px width, 1.5 text scale and 0/24/48dp bottom insets pass layout tests.

### 6. Android notification permission

Native status distinguishes not requested, granted, denied, settings required
and unavailable. Runtime permission is requested only when applicable; no
startup permission popup or duplicate Firebase/local permission request occurs.
The settings screen explains the choice, supports declining, opens Android
notification settings and refreshes actual state on resume. Setup/sync failures
are displayed independently of in-app history. Unsupported platforms do not run
Android device APIs or claim successful Android permission.

### 7. Channels

Four channels only: `emergency_sos` (maximum importance), `family_activity`
(high), `device_safety` (high), `general` (default). Channel creation does not
override user-selected channel settings.

### 8. FCM, routing and session lifecycle

- Foreground FCM uses one local notification; background/terminated notification
  payload display is delegated to FCM/Android, avoiding dual display paths.
- Launch taps are retained until the authenticated/onboarded Home shell is ready;
  there is no recursive per-frame retry loop. Logout clears queued taps.
- Existing records route to Emergency Detail, Device Detail or manager join
  requests; missing/inaccessible records safely fall back. The current user is
  rechecked after asynchronous reads; addressed payloads for another user are ignored.
- Device token refresh uses the refreshed value. Metadata writes compare actual
  stored values, skip unchanged updates and never mirror private tokens to Circles.
- Token invalidation still runs if the Firestore logout cleanup fails. Binding
  is serialized, suspended during logout and tokens rotate before a different
  account can bind. Offline token invalidation may need the next online session;
  no offline remote-revocation guarantee is claimed.
- The prepared server sender includes recipient UID, chunks multicast requests
  at 500 tokens and avoids deleting a newly refreshed token after an old-token error.
- Automatic app-event push remains **not live**: Functions are intentionally
  undeployed on Spark. Client/channel configuration alone is not end-to-end delivery.

### 9. Exact device metadata

Existing installation ID, owner UID, platform/name/pairing status, heartbeat/last
seen and screen-time fields are preserved. Added/synced: `manufacturer`, `model`,
`osVersion`, `androidApiLevel`, `appVersion`, `appBuildNumber`, private `fcmToken`,
`notificationPermissionState`, `notificationsEnabled`, `notificationCapable`,
`pushUpdatedAt`, `updatedAt`. Circle mirrors omit `fcmToken`.

### 10. Information not collected

No IMEI, IMSI, SIM serial, MAC address, advertising ID or new sensitive hardware
identifier was added. No fabricated location permission/status was introduced;
only existing modeled capabilities were extended.

### 11. Predictive back

AppPageTransitionsBuilder extends Flutter's supported fullscreen predictive-back
builder and supplies an opaque themed AppPageBackground per real route. Previously
transparent scaffolds/app bars shared a single background outside Navigator,
allowing parent and child text to mix. The route's own background now moves with
its content/header. Flutter owns interactive movement, retreat, cancellation and
the exactly-once pop; the fallback uses matching theme colors. No screenshots,
duplicate parents, heavy blur, manual pop at gesture start or disabled predictive
back were introduced. Child cancellation and completion are tested through the
real Flutter backgesture platform channel, in light and dark themes.

### 12. Verification evidence

- Latest pass after notification-cleanup completion: `flutter analyze --no-pub`
  reports no issues; all 291 Flutter tests pass; all 6 callable lifecycle emulator
  tests pass; Functions TypeScript compiles; Firestore security-rule emulator
  suite exits successfully. The Android release testing APK was rebuilt.

- `flutter analyze --no-pub`: **No issues found**.
- Full `flutter test --no-pub`: **291 passed, 0 failed**.
- Local Firestore emulator: **39 passed, 0 failed**. This is a local Firebase
  test server, not an Android emulator. Includes atomic cleanup, non-owner denial,
  installation privacy, metadata matching, global-device preservation, and existing
  invite approval/concurrency/security regressions.
- Functions TypeScript compile: **passed**.
- `git diff --check`: no whitespace errors (Windows LF/CRLF notices only).
- Android release testing build: **passed** after enabling the notification
  plugin's required core-library desugaring in `android/app/build.gradle.kts`.
- APK: `build/app/outputs/flutter-apk/app-release.apk`
  - Size: **76,557,822 bytes (73.01 MiB)**
  - SHA-256: `E43AF583BBD0D672738881580448162412BB14A140A87054C472B7CDF8229BD3`
  - APK Signature Scheme v2: **verified**, one signer.
  - Signed with the current Android debug certificate; this is a testing APK,
    not a Play Store production artifact.

### 13. Regression results

Existing authentication, onboarding, profile/address/security, image handling,
theme persistence, Plans, Circle details/lifecycle, invite/QR/join approval,
device/screen-time and responsive widget tests pass. This is automated coverage,
not a claim that future/disabled ownership transfer, location collection or paid
backend features became implemented or live in this task.

### 14. External requirements

- Deploy the reviewed `firestore.rules` to `familyemergencyapp` after the required
  explicit production approval. Previous automatic review required fresh approval
  for that exact production access-control change. Local tests do not deploy rules.
- Keep Spark/free. Do not enable billing or deploy Functions without a separate
  explicit instruction. Automatic server-triggered push therefore remains deferred.
- Connect a physical phone for grant/deny/settings, foreground/background/terminated
  notification delivery, device metadata and slow-swipe visual acceptance.

### 15. Remaining acceptance work / exact next steps

1. Obtain the exact production rules-deployment approval and deploy rules only.
2. On a disposable test Circle verify delete success, denial and failure, and
   immediate Family-list removal. Do not delete real family data for a test.
3. On Android 13+ verify permission denial/recovery and notification shade/taps;
   repeat slow, cancelled and completed back on the requested nested routes.
4. Never label background push delivery or physical-device performance verified
   until there is actual evidence. Current working-tree changes remain uncommitted.

## Phase 9 — Real Android screen-time collection (2026-09-12)

Status: **IMPLEMENTED, SECURED, TESTED, AND ANDROID-BUILT. Real-device runtime
validation and production Firestore-rules deployment remain pending.** Per the
Phase 9 acceptance rule, this section does not label the phase complete until an
Android phone grants Usage access and confirms a real sync end to end.

- Added a native Android `UsageStatsManager` bridge in `MainActivity.kt` with
  source-of-truth states `unknown`, `notGranted`, `granted`, and `unavailable`.
  Android opens the real app-specific Usage Access settings page; the app never
  fakes permission or usage values and never prompts at startup.
- Added the protected `PACKAGE_USAGE_STATS` manifest declaration. Collection is
  excluded on unsupported platforms and the UI shows an unavailable state.
- Added an in-app consent explanation before opening Android settings. Consent
  is stored locally, permission is rechecked on app resume and refresh, and a
  revoked grant stops collection and publishes the revoked state.
- Collection is tied to the stable Phase 8 installation ID. Daily records use
  deterministic IDs, so retries update the same user/device/date record instead
  of creating duplicates.
- Firestore schema:
  - private source: `users/{uid}/devices/{installationId}/screenTimeDaily/{yyyy-MM-dd}`
  - Circle mirror: `groups/{circleId}/screenTimeDaily/{uid}_{installationId}_{yyyy-MM-dd}`
  Each record stores the owner UID, installation ID, local date/timezone offset,
  actual Android foreground total, per-app totals, collection/server-sync time,
  source, and schema version.
- Circle mirroring occurs only when that exact Phase 8 device association is
  still paired. Rules bind writes to the authenticated UID, active device,
  deterministic path, active Circle membership, and paired association. Circle
  reads require active membership; outsiders and spoofed paths are denied.
- Added offline durability: a JSON pending payload is saved before Firestore
  writes and cleared only after a server-source read confirms delivery.
  Firestore's own offline queue remains active as a second layer.
- Added WorkManager periodic sync every six hours. It does not display a prompt;
  it retries pending data and collects Today only when both consent and Android
  Usage access are already granted. Manual refresh syncs the selected period.
- Progress now shows selected Circle/member/period screen-time totals and opens
  a real detail screen with consent/permission/error/no-data states, refresh,
  device count, last-sync time, and per-app usage. Device Detail shows the stored
  screen-time permission and last sync.
- Period definitions are local-calendar based: Today, Yesterday, trailing seven
  days including Today, and the previous calendar month. For overlapping
  multiple devices, each day's largest device total is used to avoid obvious
  double counting; app totals follow the selected daily device.
- `flutter analyze`: **No issues found**.
- Complete `flutter test`: **286 passed, 0 failed**.
- Firestore emulator rules: **36 passed, 0 failed**, including screen-time
  idempotency, ownership, Circle visibility, spoof prevention, and permission
  publication cases.
- Latest Android testing release build succeeded with
  `--dart-define=AUTO_VERIFY_EMAIL_FOR_TESTING=true`:
  `build/app/outputs/flutter-apk/app-release.apk`
  - Size: **75,896,591 bytes (72.38 MiB)**
  - SHA-256: `64FA97EBA9D2859EF22073E3C6DEDD25D00F84E7E9133DB5C3F3F7A7FCDCB770`
  - The current release Gradle configuration uses the debug signing key, so
    this artifact is for testing and is not a Play Store production artifact.
- No emulator was used. `adb devices -l` found no connected physical Android
  device, so real UsageStats grant/data collection could not be exercised in
  this environment.
- Production rules deployment was prepared for Firebase project
  `familyemergencyapp`, but automatic approval review rejected the persistent
  production access-control change pending explicit confirmation of that exact
  project and deploy action. No paid Firebase product was enabled.

Remaining acceptance check:

1. Connect/install on a physical Android phone, open Progress > Screen Time,
   accept sharing, enable SafeCircle in Android Usage Access, return to the app,
   refresh, and verify non-zero real app usage plus a server-synced timestamp.
2. Explicitly approve deployment of `firestore.rules` to production project
   `familyemergencyapp`, then run the rules-only Firebase deploy.

## Tab icon, label, and selected-state sizing refinement (2026-09-12)

Status: **COMPLETE.** This small follow-up standardizes tab presentation to the
approved Figma direction. No APK was built.

- Added shared tab tokens: **15sp labels** and **28dp icons**.
- Increased the custom bottom navigation height to 96dp so the larger Progress,
  Family, Home, Plan, and Profile controls retain safe spacing.
- Bottom destination icons now use 28dp consistently. The raised Home action is
  68dp with a 34dp icon. All five labels use the same 15sp size and retain the
  theme-colored selected surface, active color, and stronger selected weight.
- Applied the same 15sp label standard and selected/unselected weight treatment
  to Family Owned/Joined, Create/Join Circle, Account Personal/Address, Progress
  period, and System/Light/Dark controls.
- Increased theme selector icons to 24dp and vertical padding to preserve the
  Figma-style segmented-control proportions.
- Light/Dark responsive verification passed at 320px and 430px widths, including
  text scale 1.5: **186 tests passed, 0 failed**.
- flutter analyze: **No issues found**.
- APK was intentionally not rebuilt per the user's instruction. The existing APK
  predates this tab-only refinement.

## Consolidated UI, navigation, Circle, plans, links, and theme pass (2026-09-12)

Status: **COMPLETE in code, automated verification, analyzer, and Android
artifact.** This section supersedes older notes for the same screens.

- Rebuilt the shared dropdown as a fixed-height, bounded MenuAnchor. Labels
  always float, selected text cannot overlap the placeholder, long values
  ellipsize, and every menu is scrollable within the trigger width.
- Profile now shows a read-only avatar. Photo selection moved to Account
  Settings and participates in the same dirty state as personal/address edits.
  The new image remains a preview until **Save Settings** succeeds; cancellation
  or a failed write keeps the edit on screen.
- Main Home, Family, Progress, Plans, and Profile headers are fixed above their
  scrollable content. Their existing notification/action icons remain in the
  header.
- Circle deletion moved from Circle Settings to the Circle Detail app bar and is
  owner-only. It uses the required permanent-delete confirmation, returns to the
  Family list on success, removes the stale local Circle immediately, and stays
  on Circle Detail with an error on failure.
- Circle Settings is ordered as identity/role, lifecycle (red Leave followed by
  Transfer Ownership), secure invitation, then emergency recipients. Delete was
  removed from this screen.
- Invitations now expose only **QR Code** and **Share Link**. Manual invite/share
  code entry and display were removed. The QR encodes the same HTTPS URL that is
  shared. AuthGate retains valid app links across sign-in/profile gates and
  consumes them once; the existing callable validation, approval request, role
  enforcement, expiry, usage limit, and replay protections remain unchanged.
- Added Android custom-scheme/HTTPS intent filters, iOS custom URL registration,
  app_links, and a Firebase Hosting /join fallback page that opens the app or
  directs an uninstalled Android user to Play Store. Invalid link hosts and
  malformed codes fail closed.
- Plans now uses responsive cards that fill taller screens and scroll on compact
  screens. Profile's row is named **Plans** and pushes the same Plans screen, so
  Back returns to Profile; the bottom Plans tab remains a root destination.
- Navigation continues to use normal Material routes and system back. Android
  predictive-back support is enabled; Circle leave/delete returns unwind to the
  Family tab without forcing unrelated tabs.
- System, Light, and Dark selections now persist with SharedPreferences and are
  restored before the app renders.
- Removed the obsolete commented legacy tab implementation from
  family_shell.dart.
- flutter analyze: **No issues found**.
- Complete flutter test: **282 passed, 0 failed**.
- Build:
  flutter build apk --release --dart-define=AUTO_VERIFY_EMAIL_FOR_TESTING=true.
- APK: build/app/outputs/flutter-apk/app-release.apk
- Size: **75,480,926 bytes (71.98 MiB)**.
- SHA-256:
  352873D8A10D8C0916221EEDAB68CAEAF4E5CA3FBE24BF716D895949249CCC34.
- apksigner verification passed with APK Signature Scheme v2 and one signer.
  The current release configuration still uses the Android debug certificate,
  so this artifact is for testing.
- No emulator/device run and no paid Firebase feature was enabled.

External release setup still required:

- Replace the placeholder Android application ID
  com.example.family_emergency_app with the final Play package and publish the
  Play listing before the fallback store URL can work for real users.
- Configure the final owned HTTPS invite domain, deploy the included Firebase
  Hosting files on the Spark/free project, and host
  /.well-known/assetlinks.json using the final production signing certificate.
  Until that deployment, generated HTTPS invite links are implementation-ready
  but are not live.
- Configure the equivalent iOS Associated Domains/Apple App Site Association
  and App Store destination when the iOS release identity is available.

## App-wide UI sizing, navigation actions, profile photo, and rebuilt APK (2026-09-12)

Status: **COMPLETE in code, automated tests, responsive renders, and Android
artifact.** This pass implements the nine requested UI corrections without
enabling a paid Firebase product or changing the current subscription/business
logic.

- Added centralized typography and component sizing. Page titles use 24sp,
  app-bar titles 21sp, body/input text 15–16sp, supporting/error text 13–14sp,
  regular actions 52–56dp, and Emergency SOS 64dp/18sp.
- Family Circles Owned/Joined tabs now use a solid theme-colored selected state,
  white selected text, stronger weight, and a 48dp touch target.
- Added Circle Settings at the top-right of Family Circles. It opens the selected
  manageable Circle or the first owned/manageable Circle. The Circle Settings
  entry was removed from Profile.
- Added the notification bell throughout authenticated primary and detail
  screens, placing it beside existing top-right actions.
- Added profile-image add/edit from the Profile avatar using the device gallery.
  Images are resized/compressed and capped at 256 KiB, then stored in the existing
  Firestore user profile field as a data URL. This uses the existing Spark/free
  Firestore setup and does not enable Firebase Storage or any paid Firebase
  feature. Existing Google/network profile-photo URLs remain supported.
- Moved the Home check-in and Emergency actions to the bottom of the available
  content area. They remain scrollable when Circle cards need more vertical room.
- Replaced app form dropdowns with a bounded dropdown component whose popup width
  is constrained to its field width.
- Removed the duplicate Security entry from Profile. Security Settings remains
  inside Account Settings.
- Account Settings Personal/Address tabs and bottom navigation destinations now
  have clear theme-colored selected states.
- Added the iOS photo-library usage description required by the gallery picker.
- `flutter analyze`: **No issues found**.
- Final full `flutter test`: **274 passed, 0 failed**.
- Responsive verification covered 320×568 and 430×932, light/dark themes, and
  text scales 1.0 and 1.5. Fresh 430px light/dark render captures were also
  generated under `build/ui-verification/` and visually inspected.
- Build command:
  `flutter build apk --release --dart-define=AUTO_VERIFY_EMAIL_FOR_TESTING=true`.
- APK: `build/app/outputs/flutter-apk/app-release.apk`.
- Size: **75,162,230 bytes (71.68 MiB)**.
- SHA-256:
  `6CA61204F9E10AA74AA831E8F30EDE3F72D6B1741325CB22B31E113509B5CDA3`.
- Android `apksigner` verification passed with APK Signature Scheme v2 and one
  signer. The release configuration still uses the Android debug certificate,
  so this is a testing APK.
- No emulator/device installation was run. The remaining manual check is to open
  gallery selection on a real Android device, save a photo, restart the app, and
  confirm the stored avatar reloads. Flutter also reports the existing future
  Kotlin Gradle Plugin migration warning; it does not affect this build.

## Testing verification flow, blur validation, and rebuilt APK (2026-09-12)

Status: **COMPLETE.** The testing APK now keeps the verification screen visible
for an unverified account and enables Next. Selecting Next bypasses verification
for that in-memory authenticated session and proceeds to onboarding. It does not
alter Firebase Auth's `emailVerified` value. Signing out and signing in again, or
restarting the app, clears the session bypass and shows verification again while
the Firebase email remains unverified.

- Release builds remain strict by default. Testing bypass is enabled only when
  compiled with `--dart-define=AUTO_VERIFY_EMAIL_FOR_TESTING=true`; debug builds
  enable it by default.
- `AuthGate` stores the bypass for the current user and current widget/session
  only, then clears it when authentication returns to signed out.
- Required fields across the existing app forms now use
  `AutovalidateMode.onUnfocus`. A field does not show an error while the user is
  entering it for the first time; an invalid field validates after focus moves
  elsewhere. Explicit form submission still validates the complete form.
- `flutter analyze`: **No issues found**.
- Focused verification/auth/form tests: **14 passed, 0 failed**.
- Final full `flutter test`: **272 passed, 0 failed**.
- Build command:
  `flutter build apk --release --dart-define=AUTO_VERIFY_EMAIL_FOR_TESTING=true`.
- Artifact: `build/app/outputs/flutter-apk/app-release.apk`.
- Size: **75,095,317 bytes (71.62 MB)**.
- SHA-256: `6BAC3E2CE849E720F64CDFD160A0811519A988A68A5A6EB7668345C8F1998E56`.
- Android `apksigner` verification passed using APK Signature Scheme v2 with
  one signer. The current release configuration uses the Android debug
  certificate, so this APK is suitable for testing rather than Play Store
  publishing.
- Flutter reported a future Kotlin Gradle Plugin migration warning; it did not
  affect this build.
- No emulator or device installation was run.

## Temporary Apple Sign-In disablement (2026-09-12)

Status: **DISABLED in the app code and UI.** Email/password and Google Sign-In
remain active.

- Removed `signInWithApple()` from `AuthActions` and `AuthService`.
- Removed `AppleAuthProvider`, Apple scopes, popup/provider authentication,
  first-user profile preparation, and Apple verification-email handling from the
  client authentication service.
- Removed Continue with Apple from Login and Sign up with Apple from Signup.
- Removed the Apple method/counter from auth test fakes and added a widget test
  that confirms Apple is absent from both screens while Google remains visible.
- Existing `apple.com` provider-name rendering in Profile Security is retained so
  any historical Apple-created account remains readable and can sign out; there
  is no route in the app to start a new Apple authentication attempt.
- Firebase Console's Apple provider switch was not changed because the requested
  external Chrome browser was unavailable to Computer Use in this session. This
  does not expose Apple login in the app. When Chrome control is available, the
  console switch can also be turned off under Authentication → Sign-in method.
- `flutter analyze`: **No issues found**.
- Targeted auth/verification tests: **10 passed, 0 failed**.
- Final full `flutter test`: **271 passed, 0 failed**.
- No emulator or APK build was run.

## Superseded testing mode — automatic email verification bypass (2026-09-12)

Status: **SUPERSEDED by the latest section above.** The earlier implementation
skipped the verification screen in non-release builds. The current implementation
shows the screen and makes Next an explicit, current-session testing bypass. A
release build remains strict unless the testing dart-define is explicitly set.

## Post-Phase 8 — Email verification gate and one-time onboarding (2026-09-12)

Status: **COMPLETE in code and automated tests.** No Firebase billing change,
Cloud Function, rules deployment, Android emulator, or APK build was required.

### Implemented behavior

- Email/password signup now calls Firebase Auth `sendEmailVerification()` after
  account creation and before the user can enter onboarding.
- A signed-in user with a non-null unverified Firebase email is intercepted by
  `AuthGate` before profile/Circle resolution and shown a centered Verify Email
  card. The card displays the destination email, Check Verification, resend,
  Cancel, and Next actions.
- Next remains disabled until `User.reload()` reports `emailVerified == true`.
  The app checks once when the card opens and again whenever the app resumes, so
  returning from the email link updates the state. A manual Check Verification
  action covers browsers/platforms that do not produce a normal resume event.
- Successful verification forces an ID-token refresh before enabling Next.
  Selecting Next returns to `AuthGate`, which routes a new user through the
  existing profile/Circle onboarding flow.
- Cancel signs out safely. If the app is closed, the persisted Firebase session
  returns to the verification gate; if the user later signs in again, the same
  gate remains until Firebase reports the email verified.
- Resend uses Firebase Auth and has a 60-second UI cooldown to reduce accidental
  repeated email requests. Provider/network/throttling failures use the existing
  safe auth error mapping.
- A first-time Google/Apple account receives this extra Firebase email step only
  if that provider returns a non-null email which Firebase marks unverified.
  Google/Apple normally return provider-verified emails, so those trusted sessions
  continue without a redundant email link.
- `AuthDestinationResolver` now honors persisted `onboardingCompleted`: a user
  who completed onboarding once is routed Home even if all Circles were later
  removed. Incomplete new users still resume the correct onboarding step, while
  legacy users with an active Circle still route Home.

### Files changed/created

- Changed `lib/services/auth_service.dart`
- Changed `lib/features/auth/presentation/auth_gate.dart`
- Changed `lib/features/auth/domain/auth_destination.dart`
- Created `lib/features/auth/presentation/email_verification_screen.dart`
- Created `test/email_verification_flow_test.dart`
- Updated `test/signup_preparation_test.dart`, `test/auth_routing_test.dart`, and
  `test/theme_verification_test.dart`

### Verification performed

- Automated tests confirm the signup service sends exactly one verification
  email, Next is disabled before verification, Firebase-confirmed verification
  enables Next, resend and Cancel call the authenticated service, and completed
  onboarding does not reopen without a Circle.
- The verification card passed the existing Light/Dark responsive matrix at
  320×568 and 430×932 with text scales 1.0 and 1.5.
- `flutter analyze`: **No issues found**.
- Final full `flutter test`: **269 passed, 0 failed**.
- A real inbox/link round trip was not performed because no runtime account was
  created and the user requested no emulator/APK build. Manual verification for
  the next user-approved build: create an email/password account, confirm the
  Firebase verification email arrives, verify Next is disabled, open Verify Email
  in the email, return to the app, check verification, select Next, finish
  onboarding, restart/sign in again, and confirm onboarding is not repeated.

## Phase 8 — Device Pairing & Heartbeat (2026-09-12)

Historical Phase 8 close status: **COMPLETE within the current Firebase client
architecture.** Its tested Firestore rules and indexes were deployed to production
project `familyemergencyapp`. Firebase remains on the Spark/free plan. Phase 9 has
since been implemented as documented at the top of this handoff. Preserve all
uncommitted work across phases.

### 1. Files modified

- `firestore.rules`
- `lib/features/devices/presentation/device_screens.dart`
- `lib/features/groups/presentation/group_members_screen.dart`
- `lib/features/members/presentation/circle_member_detail_screen.dart`
- `lib/features/members/presentation/member_profile_screen.dart`
- `lib/features/shell/presentation/family_shell.dart`
- `lib/features/shell/presentation/tabs/profile_tab.dart`
- `lib/models/paired_device.dart`
- `rules-tests/package.json`
- `test/circle_lifecycle_test.dart`
- `test/light_theme_responsiveness_test.dart`
- `test/theme_verification_test.dart`
- `CODEX_HANDOFF.md`

### 2. Files created

- `lib/core/domain/device_policies.dart`
- `lib/models/device_pairing_request.dart`
- `lib/services/device_service.dart`
- `lib/services/device_heartbeat_controller.dart`
- `rules-tests/device.rules.test.cjs`
- `test/device_domain_test.dart`
- `test/device_flow_test.dart`
- `test/support/fake_device_service.dart`

### 3. Database/schema changes

- Canonical installation: `users/{ownerUid}/devices/{installationId}`. The path
  and `ownerUserId` bind an installation to its authenticated Firebase account.
- Circle projection: `groups/{circleId}/devices/{ownerUid_installationId}`. It
  records only the association needed for Circle-scoped device display and future
  telemetry authorization; it does not duplicate authentication or profile data.
- Pairing request: `devicePairingRequests/{24CharacterSecret}` with owner,
  installation, minimal display metadata, status, expiry, and use/revocation audit
  fields.
- Device removal is soft (`revoked` or `unpaired`). User profiles, memberships,
  Circles, SOS history, and future telemetry references are never cascaded away.
- Existing automatic single-field indexes cover Phase 8 queries; no additional
  composite index was required.

### 4. Migrations

No destructive migration was needed. All Phase 8 collections/subcollections are
created lazily and optional, so populated Phase 1–7 users and Circles remain
valid. A reinstall intentionally creates a new installation record; an old record
remains auditable until the user revokes it.

### 5. New/changed APIs

`DeviceActions`/`DeviceService` provides registration, account-device and
member-device streams, pairing-code create/revoke/consume, heartbeat, rename,
account revocation, and Circle unpair operations. These are authenticated
Firestore operations rather than a new HTTP endpoint. Firestore rules provide the
server-side ownership, field allow-list, timestamp, rate, and transaction checks.
No Cloud Function was deployed.

### 6. Device registration implementation

After authenticated `HomeScreen` starts, `DeviceHeartbeatController` registers
the installation. A cryptographically generated 32-character installation ID is
stored in SharedPreferences and used as the deterministic document ID; no IMEI,
serial, advertising ID, name, or model is used as identity. Registration uses a
transaction and is idempotent across launches/logins. A reinstall/app-data clear
correctly produces a new identity. Safe platform/app metadata is refreshed using
server timestamps without permitting ownership changes.

### 7. Pairing implementation

The intended member opens Profile → My Devices → Pair This Device to a Circle and
generates a code/QR. This is the device owner's consent. A Circle owner/parent
opens the registered member's Circle Member Detail, selects Pair Member Device,
scans or enters the code, confirms the intended-device consent, and submits. One
Firestore transaction validates authority, target membership, code state, expiry,
and installation ownership; it creates the deterministic Circle association and
marks the request used atomically. Cancel Pairing Code revokes an unused request.

### 8. Pairing token security

Codes contain 24 cryptographically random characters from an unambiguous
32-character alphabet, expire after 10 minutes, are single-use, and contain no UID,
device ID, auth token, or reusable credential. Only the exact-token document can
be fetched; listing requests is denied. Rules reject malformed, expired, used,
revoked, wrong-installation, wrong-member, outsider, non-manager, reassignment,
and replay attempts. QR parsing accepts only
`familyemergency://pair-device?code=...`, keeping Circle-invite QR data separate.
No pairing secret is logged.

### 9. Heartbeat implementation

The authenticated current installation updates its canonical device and active
Circle projections in place. Heartbeat writes use Firestore server timestamps for
`lastHeartbeatAt`, `lastSeenAt`, and `updatedAt`; they refresh allowed platform/app
metadata and never append heartbeat rows. Network/backend failures are caught and
retried only at the next normal interval. App startup is never blocked by a failed
heartbeat/registration request.

### 10. Heartbeat interval/thresholds

- Foreground interval: 15 minutes.
- Resume: one immediate guarded heartbeat, then the 15-minute schedule restarts.
- Backend minimum interval: 1 minute, enforced by rules to reject spam/rapid
  duplicates.
- Online through 20 minutes after the latest heartbeat.
- Stale after 20 minutes through 60 minutes.
- Offline after 60 minutes or when no heartbeat exists.

All values live in `DevicePolicy`; screens do not define their own thresholds.

### 11. Online/stale/offline logic

`PairedDevice.presenceAt()` is the single domain calculation. It prefers
`lastHeartbeatAt`, falls back to legacy `lastSeenAt`, compares UTC instants, and
returns Online/Stale/Offline from the thresholds above. Revoked and Unpaired take
priority regardless of how recent an older heartbeat is. UI converts timestamps
to local time only for display.

### 12. Device revocation/removal behavior

Account-device revoke changes canonical and Circle records to `revoked` with
server audit timestamps. Rules then reject further heartbeat. Circle unpair marks
only that Circle projection `unpaired`, leaving the account installation and other
Circle associations intact. Rename persists to canonical and existing projections
atomically, trims whitespace, rejects empty names, and caps names at 80 characters.
Duplicate display names are allowed because display names are never identifiers.

### 13. Session integration

Phase 7 Firebase Auth remains the only authentication/session system. Installation
identity is separate from Auth session history and Circle pairing. The shell owns
one lifecycle controller and disposes it when the authenticated shell is removed.
Current-device revocation shows an explicit warning and signs out locally; remote
revocation is watched while online and also triggers sign-out. The listener starts
even if initial registration is temporarily offline. Auth sign-out removes the
shell, cancels the timer/listener, and prevents further authenticated heartbeat.

### 14. FCM preparation

The canonical `users/{uid}/devices/{installationId}` location matches the existing
backend's documented future FCM target and provides a stable installation record
to which a token can later be attached/refreshed. Phase 8 does not add
`firebase_messaging`, store a token, or send SOS notifications. Phase 12 must add a
dedicated token-update operation and narrow rule allow-list before enabling it.

### 15. Phase 9/10 compatibility preparation

The deterministic installation ID plus Circle projection provides unambiguous
`ownerUserId`, `circleId`, `installationId`, and server-time association keys for
future screen-time and consent-based location documents. Phase 8 collects neither
screen-time nor location and requests no new location permission.

### 16. Routes/redirects verified

Profile now opens My Devices → Device List → Device Detail/Pairing Code. Registered
Circle Member Detail shows authorized devices → Device Detail and manager-only
Pair Member Device. Existing `Navigator` routing and `AuthGate` remain unchanged;
all entry points originate inside the authenticated shell. Legacy manual member
profiles now explain that pairing requires a registered Circle account instead of
opening an unusable device flow. Scanner input is handled only inside the
authenticated pairing screen; no unauthenticated OS deep-link route was added.

### 17. Positive tests executed and results

Flutter tests verify stable installation identity across service recreation,
current-device identification, QR/code rendering and expiry, valid pairing,
duplicate-submit blocking, online/stale/offline transitions, resume heartbeat,
remote revoke logout callback, real member-device display boundaries, and Phase
1–7 flows. The final complete Flutter run passed **257/257**.

### 18. Negative tests executed and results

Flutter/domain tests cover malformed/wrong-flow pairing input, empty code,
duplicate submission, non-manager privacy, revoked status overriding fresh
heartbeat, and startup/network-safe lifecycle behavior. Rules tests reject no-auth
registration/heartbeat, missing or malformed installation data, oversized names,
cross-user reads/writes, owner reassignment, expired/used/wrong-member pairing,
non-manager approval, rapid heartbeat, revoked heartbeat, and unauthorized device
visibility. Error, loading, retry, empty, pairing-expiry, revoked, and no-device
states are implemented without fake records.

### 19. DB/integration tests and results

Firestore emulator ran the combined Phase 1–8 rules suite: **34 passed, 0
failed**. Phase 8's 8 database tests verify deterministic canonical registration,
ownership and allow-lists, secure request creation, atomic manager consumption,
replay/incorrect-member denial, heartbeat ownership/rate control, revocation and
soft unpair, Circle preservation, and owner/manager visibility. Pairing failure
rolls back because request consumption and association creation are one
transaction.

### 20. Authorization/IDOR tests and results

User A cannot list/read User B's canonical devices, rename/heartbeat/revoke them,
change `ownerUserId`, or pair a device to User B without manager authority and an
active target membership. Normal Circle members cannot read another member's
device projection. Device owners can see their own Circle projection and Circle
owners/parents can manage active-member projections. Both UI privacy and deployed
Firestore authorization enforce these boundaries.

### 21. Regression tests and results

The final **257/257** Flutter suite covers launch, first-run behavior, auth forms,
signup preparation, account/address/security flows, Circle lifecycle, member
detail/removal, secure invite/QR/join approval, existing local state, responsive
screens, themes, and Phase 8. All passed. The combined Firestore Phase 1–8 rules
suite passed **34/34**. No existing Phase 1–7 schema relation was removed.

### 22. Flutter analyze/test result

- `flutter analyze`: **No issues found**.
- `flutter test`: **257 passed, 0 failed**.
- Formatter completed on all Phase 8 Dart sources/tests.
- Android emulator and APK build were intentionally not run per user instruction.

### 23. Backend test result

- Functions TypeScript: `tsc --noEmit` passed.
- Firestore rules emulator: **34 passed, 0 failed**.
- Production deploy on 2026-09-12: Firestore rules compiled, indexes deployed,
  and rules released successfully to `familyemergencyapp`.
- Cloud Functions were not deployed and billing was not enabled.

### 24. UI alignment/overflow review

Device List, pairing code/QR, pairing form, Device Detail, member-device section,
rename/revoke states, long names, timestamps, status chips, empty/error states, and
dialogs were added with the existing Light Theme components. Automated widget
rendering passed in light/dark themes at 320×568 and 430×932, text scales 1.0 and
1.5. The focused compact-phone suite also passed long member/device names and a
240-pixel keyboard inset without RenderFlex/layout exceptions.

### 25. Known limitations/TODOs

- Mobile OSes do not guarantee background execution. Phase 8 sends foreground and
  resume heartbeats; it does not claim continuous background presence.
- Firebase client Auth cannot selectively invalidate one device's refresh token.
  Revocation is enforced for Phase 8 Firestore device operations and triggers app
  sign-out when the installation next receives the snapshot. A future trusted
  session/token backend would be needed for cryptographic per-device session
  revocation across every Firebase API.
- Platform and app version are registered. OS version/model/manufacturer remain
  “Not reported” until a future vetted metadata package is introduced; no private
  permanent hardware identifier is collected.
- FCM token storage/delivery and location remain later phases. Screen-time is now
  implemented in Phase 9 as documented at the top of this handoff.
- Physical two-phone camera scanning, process kill/reinstall, real production test
  accounts, offline restoration, and remote revocation timing were not manually
  exercised because the user requested no emulator/APK build and no physical test
  devices/accounts were supplied. Implementation and automated rules/widget/domain
  coverage exist. Manual verification: install the next user-approved build on two
  phones; sign in as an active member on phone A and a Circle manager on phone B;
  confirm My Devices shows This Device; generate a code on A; pair it from B's
  registered Member Detail; reopen A and verify no duplicate; background/resume A
  and inspect server heartbeat timestamps; rename/unpair/revoke from the permitted
  screens; verify a normal member cannot view another member's devices and a
  revoked current device signs out when online.

## Product plan decision — recorded 2026-09-11

The agreed future entitlement model has three tiers. This is a product/schema
decision only; billing, payment providers, paid Firebase features, and entitlement
enforcement are not active yet.

- **Free Member:** may join up to 2 active Circles and use essential member safety
  features. Cannot create/own a Circle. Core SOS access must not be paywalled.
- **Plus:** may own up to **5 Circles**. Each Circle supports the owner plus up to
  **10 added members** (11 active memberships total). Plus is the first paid tier.
- **Pro (future program):** may own up to **25 Circles**. Each Circle supports the
  owner plus up to **50 added members** (51 active memberships total). Pro remains
  hidden/inactive until its later product phase.
- Subscription belongs to the account, while `owner`, `parent`, `adult`, and
  `child` roles remain scoped independently per Circle. A Plus/Pro owner can be a
  free-role member inside someone else's Circle, and a former free member who
  upgrades can own separate Circles without changing existing memberships.
- The future backend should store server-owned account entitlements and enforce
  active-membership/owned-Circle limits transactionally. Expiry must preserve
  existing data and core SOS access while blocking new Circle/member creation and
  pausing paid monitoring features. Do not trust client-supplied plan fields.

## Phase 7 — Profile Restructuring & Real Security Flows (2026-09-11)

Status: **COMPLETE for the capabilities supported by the current Firebase Auth
client architecture.** Firestore rules and indexes are deployed to production.
No Firebase billing upgrade, paid feature, Cloud Function deployment, Android
emulator run, app runtime, or APK build was performed. Do not start Phase 8
automatically.

This section is the current source of truth and supersedes older notes later in
this file that describe Profile Security as a demo or say Firebase rules may be
undeployed. All pre-existing Phase 1–6 working-tree changes remain uncommitted and
must be preserved.

### 1. Files modified

- `firestore.rules`
- `lib/features/auth/domain/auth_error_mapper.dart`
- `lib/features/profile/presentation/account_settings_screen.dart`
- `lib/features/profile/presentation/profile_settings_screen.dart`
- `lib/features/shell/presentation/family_shell.dart`
- `lib/features/shell/presentation/tabs/profile_tab.dart`
- `lib/services/profile_service.dart`
- `rules-tests/firestore.rules.test.cjs`
- `test/theme_verification_test.dart`

### 2. New files created

- `lib/services/account_security_service.dart`
- `test/account_security_service_test.dart`
- `test/security_flow_test.dart`
- `test/support/fake_security_service.dart`

### 3. Database/schema changes

- Kept one canonical private profile at `users/{authUid}`; no parallel profile,
  session, refresh-token, or security-event collection was added.
- Profile writes now have a server-side top-level field allow-list. Document UID
  must match the authenticated path UID, canonical email must match the Firebase
  Auth token email, `createdAt` is immutable, name/phone lengths and relationship
  values are constrained, and address keys, value types, lengths, and country ISO
  format are validated.
- A user's name/relationship edit updates their profile and every active Circle
  membership identity in one Firestore batch. Membership rules use `getAfter()`
  to require exact agreement with the authenticated user's resulting profile;
  roles and Circle ownership cannot be changed through this path.
- No Phase 7 index was required. Deletion readiness reuses the existing active
  Circle membership query/index.

### 4. Migrations added

- None. The existing schema was extended only through optional existing fields
  and stricter write validation. There is no destructive migration. Production
  user/group data had already been manually cleared by the user before Phase 7.

### 5. API endpoints added or changed

- No HTTP or callable endpoint was added. Security actions use Firebase Auth's
  authenticated current-user operations: password credential reauthentication,
  `updatePassword`, `verifyBeforeUpdateEmail`, email verification, token refresh,
  and local Firebase sign-out.
- No Cloud Function was deployed, preserving the Firebase Spark/free plan.

### 6. Profile flows completed

- Profile now separates signed-in identity, Account Settings, Security,
  notifications, Circle/plan navigation, theme, and logout.
- Account Settings edits only the current authenticated user's name,
  relationship, and optional address. Name is trimmed, required, and capped at
  80 characters. Address fields are capped at 200 characters. Save is guarded
  against repeat submission and unsaved edits retain Save/Discard/Keep Editing.
- Saved name/relationship propagates atomically to active membership displays,
  refreshes the shell/profile view, and updates the Firebase Auth display name.
- Existing Firebase/Auth profile image URL is rendered with an initial fallback.
  Image upload/editing is not exposed because Firebase Storage/upload validation
  is not part of the current architecture.

### 7. Security flows completed

- Replaced the old demo security/deletion UI with real provider-aware controls.
- Password accounts can change password only after current-password
  reauthentication. New/confirm validation, different-password enforcement,
  8–128 character policy, provider/network errors, duplicate-submit protection,
  visibility toggles, and sensitive-field clearing are implemented.
- Password accounts can request a normalized new email only after
  reauthentication. Firebase sends verification before changing the canonical
  Auth email; the old email remains active on failure or until verification.
  Refresh forces a Firebase ID-token refresh and safely synchronizes the verified
  canonical email to Firestore.
- Email verification status and a real verification-email action are shown.
  Provider-managed accounts do not receive unsupported password/email controls.
- Security errors are user-safe; duplicate-email handling does not identify the
  other account. Source audit found no password/token logging or persistence.

### 8. Session and logout behavior

- Security displays the current Firebase session as “This device”, provider,
  account creation time, and Firebase last-sign-in metadata.
- Firebase client SDK does not provide a trustworthy per-device active-session
  list or selective “logout other devices” operation. Those controls are not
  faked; the UI explicitly states the limitation. No spoofable sessions collection
  was introduced ahead of Phase 8.
- Normal logout keeps the existing confirmation, clears the UID-scoped signup
  draft, signs out Firebase locally, performs Google provider cleanup best-effort,
  and lets `AuthGate` replace the authenticated shell with Login. A user cannot
  navigate Back into the disposed authenticated shell.

### 9. Routes and redirects verified

- Existing direct `Navigator` routes are reused: Profile → Account Settings →
  Security → Change Password/Change Email/Delete Account Preparation.
- All Phase 7 routes originate inside the authenticated `HomeScreen`; there are
  no named/deep protected routes in the current app. `AuthGate` remains the single
  auth source of truth and returns logged-out users to Intro only on the first
  install launch, otherwise Login.

### 10. Positive tests executed

- Real service tests verify password reauthentication occurs before Firebase
  password update, email normalization/reauthentication starts Firebase's
  verified-before-update flow, and logout clears auth plus signup draft.
- Widget tests verify supported security controls, current-session presentation,
  verification-pending email behavior, and Circle-owner deletion blocking.
- The full Flutter regression suite passed **232/232** on 2026-09-11.

### 11. Negative tests executed

- Password tests cover weak/identical values before reauthentication, mismatched
  form data, repeated submit, and wrong-current-password safe error mapping and
  field clearing. Provider-only accounts hide unsupported controls.
- Rules tests reject unauthenticated/cross-user access, UID/email/role tampering,
  unexpected profile fields, oversized names, invalid relationships, malformed or
  oversized address values, invalid country ISO, and unsynchronized membership
  identity changes.
- UI tests cover missing profile/error/retry behavior through the existing auth
  and screen suites. Provider-network failures are handled but were not sent to a
  real production account because no test credentials were supplied.

### 12. Database tests and result

- Firestore emulator ran the combined database/rules suites against an isolated
  demo project: **26 passed, 0 failed**. Tests include canonical single-profile
  creation, IDOR denial, atomic profile/membership identity propagation, caller-
  scoped deletion dependency lookup, existing Circle access/integrity, and the
  full Phase 6 invite/join approval/rejection/concurrency regression.

### 13. Authorization/IDOR tests and result

- Authenticated User A can read/update only `users/A`; reads and updates of
  `users/B` fail. Path UID manipulation, profile email tampering, unexpected
  identity fields, self-membership spoofing, outsider Circle queries, and another
  user's deletion-dependency query all fail in the emulator suite.
- Password/email operations accept no client UID and operate only on
  `FirebaseAuth.currentUser`, preventing a request-body/route IDOR path.

### 14. Regression tests and result

- Full Flutter suite: **232 passed, 0 failed**. It includes launch/intro/auth,
  validation, profile/address, Circle lifecycle, secure invite/QR/manual join,
  pending/approve/reject flows, member screens, theme, and responsive coverage.
- Combined Firestore Phase 1–7 rules suite: **26 passed, 0 failed**.
- Existing production rules/index deployment completed successfully after the
  final rules test. Phase 6 authorization behavior remains covered.

### 15. Flutter analyzer/test result

- `flutter analyze --no-pub`: **No issues found** (125.5 seconds).
- `flutter test --no-pub`: **232 passed, 0 failed** (64 seconds).
- `git diff --check`: no whitespace errors; only expected LF/CRLF warnings.

### 16. Backend test result

- Functions TypeScript `tsc --noEmit`: **passed**.
- Firestore rules compiled and the local emulator suite passed **26/26**.
- Final `firestore.rules` and `firestore.indexes.json` deployment to production
  project `familyemergencyapp`: **successful**. No Functions/billing change.

### 17. UI overflow/alignment review result

- Phase 7 security, password, email-change, deletion-preparation, and account
  screens were rendered in automated widget review at **320×568** and **430×932**,
  Light and Dark themes, and **1.0/1.5** text scales. Initial and bottom-scrolled
  frames produced no Flutter layout exception or RenderFlex overflow.
- Long current email is ellipsized in the Profile row. Long email, no avatar,
  validation/error messages, loading, and deletion dependency states are covered.
- Android emulator/device visual inspection was not performed because the user
  explicitly said it is not required. No APK was built.

### 18. Known limitations and manual checks

- Multi-device session listing/revocation cannot be implemented securely through
  the current Firebase client SDK. A future trusted backend can add server-owned
  sessions and token revocation; Phase 7 deliberately does not create fake device
  records or mix in Phase 8 pairing/heartbeat logic.
- Hard account deletion is intentionally disabled until a trusted backend cleanup
  transaction and product retention/ownership policy exist. The current real
  readiness check lists owned active Circles and prevents orphan-producing deletion.
- Profile image upload is not implemented because no validated Storage pipeline is
  configured. Existing Auth/provider photo URLs display correctly.
- Real password/email verification was not executed against a production user;
  service/provider calls were verified with mocks and authorization/database logic
  with the Firestore emulator. Manual provider verification requires a disposable
  password account: change password, re-login with the new password, request an
  email change, open Firebase's verification link, restart/refresh Security, and
  confirm both Auth and `users/{uid}.email` show the verified address.
- No Android emulator, physical-device run, APK, Functions deploy, paid Firebase
  feature, or Phase 8 work was performed.

## Login, first launch and form fixes — 2026-09-11

- Reproduced the reported post-login error in rules tests: `hasAnyGroup` queried
  groups using only `memberIds`, while the read rule called `isMember(groupId)`
  through `get()` and required active status. The list query failed with
  `permission-denied`; AuthGate incorrectly presented it as a connection problem.
- Both startup lookup and Circle subscription now query `memberIds` + active
  `status`. Group reads authorize against `resource.data`; deleted groups and
  outsiders remain denied. Added the composite index. Rules and indexes deployed
  successfully to `familyemergencyapp` on Spark, without Functions/billing changes.
  Legacy groups without `status: active` are excluded; do not restore obsolete data.
- Signup/provider authentication now exposes a profile-preparation future so
  AuthGate waits for the profile write before choosing onboarding. A UID-scoped
  in-memory signup draft preserves name/phone if initial profile creation fails.
  Recovery preserves that phone when creating the missing document. No passwords
  are retained in this draft. Startup errors use the actual Firebase error mapping.
- Removed Form-wide auto-validation throughout the app. Individual fields validate
  only after their own edits; explicit Submit/Save still validates the whole form.
  Increased compact form gaps to 18 logical pixels across auth/profile/member forms.
- `IntroPreferences` uses shared_preferences to persist `intro_seen` immediately
  on first launch. Later signed-out launches go to Login; authenticated sessions
  continue to the appropriate account screen. Clearing app storage/reinstalling
  resets this local preference. Intro completion is no longer a static run-only flag.
- Onboarding receives the persisted signup name/phone. Profile setup prefills name
  and displays phone read-only; Circle onboarding displays both. Phone entry remains
  signup-only. Address/country work below is preserved.
- Full Flutter suite passed 205 tests; security suite passed 22 tests, including
  the previously failing login query, empty/new-account results, and access denials.
  Final targeted onboarding/first-launch suite passed all 5 tests. Production
  `groups(memberIds CONTAINS, status ASCENDING)` index is confirmed READY.
- Dependencies resolved successfully. Windows plugin junctions were created under
  ignored `windows/flutter/ephemeral/.plugin_symlinks` to avoid requiring Developer
  Mode; no machine settings changed. No Android emulator or APK build was run.
  The APK below is obsolete: an updated APK is required for these app/query fixes.
  End-to-end verification on the user's signed-in phone remains a manual check.

## Country names and account address — 2026-09-11

- Signup and the new Account Settings > Address tab share `CountryNameField`:
  country lists and selected values show full country names. ISO codes remain
  internal persistence values; signup keeps the dialing prefix in the phone input.
- Phone input is now only in signup. Removed it from profile completion/recovery,
  Account Settings, the legacy profile form, and member editing. Existing phone
  data and member contact display are preserved. Provider profile completion no
  longer requires a phone, and completion does not overwrite signup phone data.
- Profile Settings > Account Settings now has Personal and Address tabs. Optional
  address fields: street, apartment/address line 2, city, state/province, postal
  code, country. Saved to `users/{uid}.address` with keys `line1`, `line2`, `city`,
  `region`, `postalCode`, `countryIso`; profile parsing tolerates old/malformed data.
- Address changes participate in unsaved-change protection. Failed saves keep
  edits available for retry; personal and address persistence are independent.
- Verification: full Flutter suite passed 200 tests before final member input
  cleanup and the additional country-selection test. Final targeted address and
  Circle lifecycle suite passed all 14 tests; `flutter analyze` found no issues.
- No emulator or Firebase/billing changes. The APK recorded below predates these
  UI changes; rebuild it when an updated installable APK is requested. Live address
  persistence on a signed-in device remains a manual check.

## Latest APK rebuild — 2026-09-11, 11:26 PKT

After the user deleted the previous APK, `flutter build apk --release` succeeded
again (79.7 seconds). Verified artifact:
`D:\My Projects\family_emergency_app\build\app\outputs\flutter-apk\app-release.apk`.
Size: 74,534,192 bytes (71.08 MiB). SHA-256:
`27D5DEBE225589B7FAF55F57DAF651080C8AD1D7B9B7521953A858FED56BC1C2`.
`apksigner verify --verbose` passed (v2). The existing debug-key signing for
release-mode testing is unchanged. No emulator/device run was performed.

## Phase 6 — Secure invite, QR, join request, and approval (2026-09-11)

Phase 6 is implemented in the current uncommitted working tree. Preserve every
listed change. The production project remains on Firebase Spark/free: tested
Firestore rules were deployed, no Cloud Function was deployed, and no billing or
paid Firebase feature was enabled.

Implemented lifecycle:

- Circle owners and parents can generate a cryptographically secure 24-character
  invite using `Random.secure`. Codes use an unambiguous alphabet, are displayed
  in groups of four, expire after seven days, allow at most 20 approvals, require
  approval, and can be revoked or regenerated.
- `circleInvites/{token}` is the invite lookup. Authenticated users may only get a
  document when they already know its exact high-entropy token. Invite collection
  listing is manager-only. Firestore rules use `request.time` for expiration.
- QR codes contain only `familyemergency://join?code={token}`. Manual input and QR
  payloads share one strict parser. The scanner guards duplicate callbacks and
  presents camera-denied, unavailable-camera, and initialization error states.
- A valid invite creates one pending document at
  `groups/{circleId}/joinRequests/{requesterUid}`. It does not create membership.
  Pending onboarding state survives restarts through `pendingJoinCircleId` and
  `pendingJoinInviteId` profile fields and can be cancelled. The authenticated
  main shell also resumes this state for already-onboarded users.
- Owners/parents can approve or reject pending requests. Approval is one atomic
  Firestore transaction updating the Circle member/role cache, membership,
  request, invite usage/status, and user profile. Rules validate the same
  coordinated `getAfter` state and restrict the new role to `adult` or `child`.
- Existing members are detected before request creation. Removed/inactive members
  may rejoin only by creating a fresh valid request and receiving manager approval.
- Existing-member and approved-request outcomes return the Circle ID to the shell;
  the shell waits for the authorized Circle snapshot and opens Circle Detail.
- Share/QR, manual join, pending state, review list, approval/rejection dialogs,
  Circle/member entry points, and onboarding routing are connected to the existing
  light UI and service architecture. A displayed invite automatically changes to
  expired state at its cutoff, even if no Firestore snapshot changes.
- The obsolete immediate-join `createCircleInvite` and `redeemCircleInvite`
  implementations were removed, together with the unused nested `invites` and
  `inviteLookup` rule blocks. Future-upgrade Phase 5 lifecycle Functions and
  third-party authentication dependencies were preserved. No Function is deployed.

Primary files:

- `lib/core/domain/invite_code_policy.dart`
- `lib/models/circle_invite.dart`
- `lib/models/circle_join_request.dart`
- `lib/services/circle_join_service.dart`
- `lib/features/groups/presentation/share_circle_screen.dart`
- `lib/features/groups/presentation/qr_scanner_screen.dart`
- `lib/features/groups/presentation/join_circle_screen.dart`
- `lib/features/groups/presentation/join_requests_screen.dart`
- `lib/features/auth/presentation/onboarding/circle_onboarding_screen.dart`
- `firestore.rules`
- `rules-tests/invite.rules.test.cjs`
- `test/invite_domain_test.dart`
- `test/invite_widget_test.dart`

Verification completed:

- `flutter analyze --no-pub`: **No issues found**.
- Full `flutter test --no-pub`: **197 passed, 0 failed**.
- Focused Phase 6 plus responsive UI run: **12 passed, 0 failed**.
- Combined Firestore emulator rules suite: **20 passed, 0 failed** (the Phase 6
  invite subset is **11 passed, 0 failed**).
- Phase 6 rules include direct self-membership/self-approval denials, unauthorized
  invite/review denial, revoked/expired rejection, atomic final-use exhaustion,
  authorized rejection without membership, double-approval concurrency, and
  approve/reject race coverage.
- Functions TypeScript `tsc --noEmit`: passed.
- Layout tests cover 320x568 and 430x932 viewports, 1.0 and 1.5 text scale,
  long Circle/requester/relationship/email values, invite QR/code/link, and
  pending/review states. No RenderFlex or layout exception was observed.
- `git diff --check`: no whitespace error; only expected LF/CRLF warnings.
- Production `familyemergencyapp`: `firestore.rules` compiled, uploaded, and
  released successfully again after the refactor on 2026-09-11.
- User later overrode the earlier no-APK restriction. `flutter build apk
  --release` completed in 773.8 seconds and produced
  `build/app/outputs/flutter-apk/app-release.apk` (74,534,192 bytes / 71.08 MiB,
  SHA-256 `27D5DEBE225589B7FAF55F57DAF651080C8AD1D7B9B7521953A858FED56BC1C2`).
  Android build-tools 37.0.0 `apksigner verify` passed using APK Signature v2.
  The current Gradle release configuration deliberately uses the Android debug
  signing key, so this APK is installable for testing but is not Play Store
  production-signed. No emulator or device run was performed.

### Production old-user cleanup and refactor (2026-09-11)

- A count-only Firebase Authentication audit found **3** old accounts. All three
  were permanently batch-deleted; the follow-up API check returned **0 remaining**.
  No Auth export was retained and no email/UID was printed.
- Firestore audit found **2** orphan `users` documents and **2** `groups`
  documents. Both Circles were verified to be fully owned by and composed only of
  those orphan user profiles. `circleInvites` and `inviteLookup` were already empty.
- The user subsequently reported manually deleting the remaining `users` and
  `groups` collections in Firebase Console. Treat the production app data as a
  fresh start. This manual deletion was not independently observed by Codex;
  remember that deleting parent documents does not necessarily remove orphaned
  subcollections, although current rules make them inaccessible without a live
  parent Circle/user document.
- Refactor removed 138 lines of unreachable legacy immediate-membership Function
  logic, unused crypto/timestamp imports, two obsolete Firestore rule paths, and
  exposed internal helper surface. Repeated invite revocation timestamps now use
  one server transform. Required future Firebase upgrade lifecycle Functions,
  Cloud Functions dependency, and Google/Apple authentication code remain intact.
- Post-refactor verification: Flutter analyzer clean; Flutter **197/197**; combined
  rules **20/20**; Functions TypeScript compile passed; refactored production rules
  deployed successfully. The release-mode APK described above was subsequently
  built; no emulator or app runtime was performed.

Current status: **PARTIALLY COMPLETE** against the original Phase 6 acceptance
text, solely because no emulator/device app runtime was performed. Real camera
permission/scanning, platform share sheet, clipboard, and
multi-account production UI behavior therefore remain unverified on a device.
Source, static analysis, widget/domain tests, concurrency tests, Firestore rule
tests, free-plan rules deployment, and an installable release-mode APK are
complete. Do not launch an emulator unless the user changes that instruction.

Exact next step when device/runtime work is authorized: run the installed app on
two authenticated accounts and verify generate → scan/manual validation → pending
→ approve/reject → membership/redirect, plus camera denied/permanently denied,
share/clipboard, revoked/expired while open, and app-restart states. Functions
must remain undeployed while the project stays on Spark/free.

## Phase 5 — Circle lifecycle and member details (2026-09-10)

Phase 5 is implemented locally on `main` at the existing dirty working tree. The
earlier Light/Dark work below is preserved. Do not discard or overwrite it.

Implemented:

- Shared Circle-name policy: trim, 2–60 characters, Unicode/punctuation support,
  control-character rejection, and the same validation in onboarding and shell.
- Robust Circle, membership, and user-profile parsing with least-privilege and
  unavailable-state fallbacks for missing or malformed Firestore data.
- Atomic Circle creation with owner membership plus `activeCircleId`/`circleIds`
  profile references.
- Live Circle list/detail/settings/member-detail streams. Detail routes close
  safely when the Circle is deleted or access is revoked.
- Registered memberships are now the source for member lists. Rows open Member
  Detail with UID, name, email, relationship, role, and status; device/progress
  values remain explicitly unavailable instead of being fabricated.
- Role-aware rename, remove-member, leave, and soft-delete flows with confirmation,
  in-flight guards, readable errors, and safe navigation after lifecycle changes.
- Callable backend operations `removeCircleMember`, `leaveCircle`, and
  `deleteCircle` coordinate Circle, membership, and profile references in
  transactions. Owners cannot leave; parents cannot remove owners/parents;
  normal members cannot remove anyone.
- Firestore rules require active Circle membership for reads, reject direct
  lifecycle/membership mutations, constrain manager edits, and require emergency
  recipients to be current member IDs.

Verification completed:

- `flutter analyze --no-pub`: no issues.
- Full `flutter test --no-pub`: **185 passed, 0 failed**.
- Focused Circle lifecycle/widget suite: **10 passed, 0 failed**.
- Firestore emulator rules suite: **9 passed, 0 failed**.
- Auth/Firestore/Functions lifecycle integration suite: **6 passed, 0 failed**.
  It covers owner and parent removal, denied adult removal, denied owner leave,
  adult leave, owner-only deletion, reference cleanup, and concurrent removal.
- Functions TypeScript: `tsc --noEmit` passed.
- Pixel_7 (`emulator-5554`) runtime: Home → Family Circles → Circle Detail →
  Member Detail and Circle Settings opened against the authenticated Firebase
  account. The active owner, one-member count, relationship, email, role, and
  owner actions rendered correctly. Filtered logcat showed no Flutter or Android
  runtime exception on these screens.
- No production Circle/member data was mutated during runtime verification.

Deployment decision: keep production project `familyemergencyapp` on the free
Spark plan. Firestore rules were compiled and released successfully. The callable
Functions implementation remains complete in source and is covered by local
emulator tests, but it must not be deployed or activated until the user explicitly
changes this decision in a future phase. A production inventory check confirms
that the project currently has no deployed Functions, so no paid Functions feature
is active.

During real callable-emulator testing, `firebase-admin` v13 exposed an incompatible
namespaced `admin.firestore.FieldValue` access. The implementation now imports
`FieldValue` and `Timestamp` from `firebase-admin/firestore`; TypeScript compilation
and all six lifecycle integration tests pass after the fix.

Current Phase 5 status for the approved free-plan scope: **COMPLETE**. Application
source, production Firestore rules, and local multi-account callable verification
are complete. Production remove/leave/delete remain intentionally inactive while
the project stays on Spark; do not request or perform a Blaze upgrade. If the user
explicitly authorizes paid backend activation in a future phase, deploy the already
completed Functions and verify their production inventory. Ownership transfer
remains intentionally deferred to Phase 6+; an owner can delete a Circle but
cannot leave it.

Primary Phase 5 files:

- `lib/core/domain/circle_policies.dart`
- `lib/core/domain/circle_error_mapper.dart`
- `lib/services/group_service.dart`
- `lib/features/groups/presentation/group_members_screen.dart`
- `lib/features/groups/presentation/group_settings_screen.dart`
- `lib/features/members/presentation/circle_member_detail_screen.dart`
- `lib/features/shell/presentation/tabs/members_tab.dart`
- `functions/src/index.ts`
- `firestore.rules`
- `test/circle_lifecycle_test.dart`
- `rules-tests/firestore.rules.test.cjs`
- `rules-tests/circle-lifecycle.integration.test.cjs`

Generated `.pnpm-store` cache from the local Functions check was removed. No
production data was changed by the integration tests. No commit, push, Functions
deployment, or release build was performed; production Firestore rules were
deployed with the user's explicit authorization.

## Issue-resolution completion — 2026-09-10

The reported Phase 1 follow-up defects are fixed in the D-drive workspace:

- Theme switching keeps the Navigator under one stable background widget tree,
  preventing the Flutter `_dependents.isEmpty` assertion seen when selecting Dark.
- Home no longer combines `IntrinsicHeight` with a nested `LayoutBuilder`. A live
  authenticated group now renders its card, check-in and Emergency actions instead
  of leaving the shell body blank.
- Profile uses a reusable three-choice `System | Light | Dark` selector. Every
  label remains visible and the selected choice has an explicit emerald gradient.
- Circle onboarding tabs now follow the reference's compact underline treatment.
  Create and Join retain independent Form keys; invalid required fields add a red
  marker to the corresponding child tab and show field text only inside that tab.
- The wider Light/Dark responsive implementation described below remains intact.

Final verification: `flutter analyze --no-pub` reports no issues and the complete
`flutter test --no-pub` suite passes **175 tests**. The updated debug app was built,
installed and launched on Pixel_7 (`emulator-5554`). Live emulator checks confirmed
the populated Home screen renders, System/Light/Dark labels are visible, and Dark
selection completes without a Flutter exception. Captures are in ignored build
output: `build/ui-verification/emulator-fixed.png`, `profile-fixed.png`, and
`profile-dark-fixed.png`.

## Latest continuation — Phase 1 Light/Dark verification (2026-09-09)

This section supersedes the older no-Dark/no-emulator constraints below. The user
explicitly requested Phase 1 (Light verification, Dark implementation, responsive
verification), then an emulator app run. Release APK/AAB and backend deployment
remain outside this phase. Continue only from the D-drive repository.

The shared chat `https://chatgpt.com/s/cx_6aa1985198a48191956a1bda5e6c88b3`
was read in the browser. Its final turn stopped during Phase 1 without a final
completion message. Existing local changes were retained and verification resumed.

Implemented in this phase:
- Context-based semantic palette for headings, body/muted text, cards, borders,
  primary actions, success and danger surfaces. Shared Light widgets now support
  both themes without changing their public constructors or backend contracts.
- Dark Material styling for fields, buttons, dialogs, menus, sheets and snackbars.
- Theme-aware intro, device/progress, sharing, account, Circle and notification UI.
- Fixed compact/large-text login and signup wrapping; fixed Material ancestors for
  visible ListTile ink effects. Plan content is independently testable and uses
  intrinsic card heights; prices inherit the app font and respect text scaling.
- Moved shell state mutations into State methods and corrected the account
  async-context guard; retained existing persistence and navigation callbacks.

Verification so far:
- Full `flutter test --no-pub`: **173 tests passed**.
- `flutter analyze --no-pub`: **No issues found**.
- Additional real-font capture run: **138 theme tests passed**, covering 17
  standalone screens in Light/Dark, 320x568/430x932, 1.0/1.5 text scales, below-fold
  scrolling, theme switching/System brightness, account keyboard and exit dialog.
- `build/ui-verification/` contains 34 430x932 screen renders (ignored build output).
  Capture uses `--dart-define=CAPTURE_UI=true` and requires
  `build/ui-verification/fonts/Manrope.ttf` downloaded from the official Google
  Fonts repo (`ofl/manrope/Manrope[wght].ttf`). Normal tests need no font download.
- Real-font screenshots reviewed include login, signup, account, plan, sharing,
  device and intro. Reference landscape illustrations remain vector/icon
  placeholders, not pixel-identical final artwork. Authenticated Firebase-driven
  screen/state coverage still needs emulator inspection; 17-screen tests are not
  proof of all 28 screens or live backend behavior.
- Pixel_7 is connected as `emulator-5554`. `flutter run -d emulator-5554` is in
  progress through Gradle assembleDebug; do not claim launch until confirmed.

Next: finish emulator launch, inspect the visible app and available authenticated
screens, record actual launch/visual results here. Any further uncovered UI defects
should be fixed and tested before claiming full Phase 1 completion.


Last reviewed: 2026-09-09  
Authoritative workspace: `D:\My Projects\family_emergency_app`  
Current branch: `main`  
Current HEAD at this update: `4e08667` (`New UI Design + New Structure`)  
Remote: `origin https://github.com/mafaq2502-creator/Apps.git`

Latest handoff update: after completing the requested seven-point Light Theme UI
pass. The implementation and this documentation are local and uncommitted; all
must be preserved together.

## Read this first

This file is the entry point for a new Codex session. Work only in the D-drive
workspace above. A C-drive copy was used by an older session and is not the
source of truth.

The requested seven-point **light-theme UI** implementation pass is now covered
in source while preserving existing Firebase, authentication, CRUD, validation,
and navigation boundaries. Clean full-suite execution and pixel-level screenshots
remain release verification gates because this Codex sandbox cannot traverse a
native Pub-cache package during Flutter tests. Do not reimplement the seven points
from scratch; use the Active task section as the authoritative latest state.

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

Some screen-status paragraphs below describe the state before the latest
seven-point pass and retain historical “Remaining” notes. The **Active task** and
latest verification sections supersede those notes. Prefer current source code
and the Active task section when they conflict.

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

### Verification for the latest seven-point completion batch

- Changed Dart sources were parsed by `dart format`; formatting was applied where
  the sandbox permitted it. `git diff --check` returned no whitespace errors.
- Targeted `dart analyze` passes reported **No issues found** for Account,
  Progress, Device, Share Circle, Group Members, Group Settings, and Member
  Profile sources. The remaining Firebase-importing changed files reached only
  environment-caused `firebase_auth` URI/type errors. A normal full analyzer
  result could not be produced because analyzer child processes were denied
  traversal of installed Pub-cache packages and consequently reported external
  package URIs as missing.
- The expanded responsive widget test was started, but Flutter stopped before
  test compilation with: `BuildInput.packageRoot ... objective_c-9.5.0 does not
  exist as a directory`. PowerShell confirmed that directory exists. Treat this
  as a sandbox/Pub-cache permission blocker; do not call the test passed or failed.
- No emulator, app run, APK, release build, Firebase deployment, dependency
  resolution, or backend test was performed.

## Active task: light-theme UI implementation

Status: **all seven requested UI implementation points are now covered in code;
automated visual execution is environment-blocked and must be rerun before a
release claim**. No service, model, Firebase contract, dependency, platform
configuration, Dark Theme, emulator, application run, APK, or release build was
changed or started in this batch.

1. **Account Settings — implemented:** the route now owns reactive name and
   relationship edit state, validates input, enables Save only when dirty, shows
   saving/error state, and protects Back with Save/Discard/Keep Editing. It passes
   edits through the existing shell/ProfileService callback, displays persisted
   country ISO/calling-code data, keeps verified email/phone read-only, opens
   Update Password directly, and refreshes the profile after a successful save.
   Current Plan and Circle Settings/Details navigation from the Profile hub are
   now connected to existing screens.
2. **Truthful data and actions — implemented:** sample device names, battery,
   storage, screen-time totals, charts, app usage, check-in history, fallback
   phones, and unconditional online dots were removed from active UI. Screens now
   show real available values or explicit unavailable/not-paired/no-history
   states. Pair, Unpair, Call, role editing, leave, transfer, upgrades, and links
   state that their backend is unavailable instead of pretending success.
   Connected Circle, notification, and emergency operations have clearer
   success/error/retry feedback. Emergency Detail no longer invents “Just now” or
   pretends its alert can open an unlinked member.
3. **Selectors and sharing — implemented:** Progress has working Circle and
   member selectors plus Today, Yesterday, Last week, and Last month selection.
   Screen-Time and Check-In detail periods are interactive. Share Circle has
   working QR/Invite Code/Invite Link tabs and uses the existing callable service
   for the real expiring invite code. Because no QR/deep-link dependency or
   contract exists, QR and joining-link tabs are explicitly unavailable rather
   than displaying a fake/scannable-looking value.
4. **Circle/member hierarchy — implemented for current contracts:** Owned/Joined
   Circle scope, Circle cards, selected member counts, Circle detail, members,
   empty state, settings/share navigation, Member Detail, device/progress links,
   and member notification settings are present. Manual member CRUD and registered
   app-user invitation are visibly separate. Member removal now confirms and
   explains that the registered account is not deleted. Unsupported membership
   role/ownership operations remain honest unavailable states.
5. **Reference layout pass — implemented:** existing splash/intro, auth and Circle
   onboarding layouts remain intact; Home/navigation, Family hierarchy,
   notifications, emergency screens, Progress, Profile/account/security, and Plan
   use the saved light palette and rounded hierarchy. Plan is now vertically
   scroll-safe while retaining the two-card reference composition. The product
   name was not changed from the app's approved current name.
6. **Modal/state frames — implemented for available flows:** SOS and logout
   confirmations, the retained three-step delete-account demo, country and
   relationship/role selection, account Save/Discard/Keep Editing, member removal,
   loading, success, empty, disabled, error, and retry presentations are covered.
   Security and unsupported platform capabilities remain clearly described as
   demo/unavailable; no fake backend was introduced.
7. **Responsive coverage — implemented, execution pending environment repair:**
   `test/light_theme_responsiveness_test.dart` covers compact/tall sizes, long
   names/details, intro navigation, Progress/Check-In/Device/Pairing, Account
   Settings, Share Circle tab states, and Yesterday selection. Dart parsing and
   `git diff --check` complete without a changed-file syntax/whitespace finding.
   The current sandbox cannot traverse the installed Pub cache from Flutter's
   native-assets child process, so widget tests stop before compilation at
   `objective_c-9.5.0 does not exist as a directory`. The directory exists; this
   is an execution-permission problem, not an app test failure. Do not record the
   tests as passed until rerun in the user's normal PowerShell/Cursor environment.

The approved design plan contains 28 navigable screens plus modal/state frames.
The source implementation is now complete for the current UI-only scope, while
pixel-level screenshot approval and a clean automated run remain release gates.
Dark Theme remains deferred until the user explicitly starts it.

## Known issues and risks

- The current UI code covers the seven-point Light Theme checklist, but pixel-level
  screenshot verification and a clean analyzer/widget-test run remain release
  gates because of the sandbox/Pub-cache restriction described above.
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

1. Confirm the workspace is exactly `D:\My Projects\family_emergency_app`, run
   `git status --short`, and preserve every local change listed by Git.
2. Do not repeat the broad UI implementation audit. First run formatting,
   `flutter analyze --no-pub`, and the responsive test in a normal PowerShell or
   Cursor terminal that can traverse the Pub cache. The current Codex sandbox's
   native-assets child process cannot do so.
3. If verification passes, produce widget-render screenshots for the compact and
   tall Light Theme sizes and compare them to
   `docs/design-references/all-screens-light-theme.png`. Fix only concrete visual
   mismatches discovered in those renders and update this handoff with evidence.
4. Keep services, models, Firebase paths, validation, dependencies, and platform
   configuration unchanged. Unsupported pairing, telemetry, deep links, push,
   payments, and security backends must remain honest unavailable/demo states.
5. **Do not launch an emulator, run the app, build an APK/release, deploy Firebase,
   or start Dark Theme** unless the user explicitly changes those instructions.
6. After clean verification and visual approval, update the verification and
   definition-of-done sections below. Do not claim tests passed without their real
   output.

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
- Formatting, analyzer, and tests pass in an environment that can traverse the
  installed Pub cache.
- Screens and modal/state frames are visually inspected against the reference
  through widget renders/screenshots within the user's no-emulator/no-APK
  constraint. Any unverified coverage is explicitly reported.
- The seven requested implementation items are complete in source. The definition
  of done remains verification-pending until a normal environment produces a clean
  analyzer/test run and widget-render comparison; no implementation checklist item
  is intentionally left open.
