# AliveCircle implementation reference

Master UI references are stored in `docs/design-references/` for both light and
dark themes. All future screen UI work should use those images together with
the approved application flow. The `SafeCircle` text inside the images remains
a visual placeholder until an app rename is explicitly approved.

Baseline commit reviewed: `5e0328d4e39a800697b5aefed311b3697002a71d`

## Current delivery status

- Phase 0 complete: baseline analyzer and tests passed.
- Phase 1 started: reusable floating-label form field added; shell/application
  controller extraction remains.
- Phase 2 complete for the target domain: Circle roles, memberships, invites,
  paired devices, indexes and compatibility strategy are defined.
- Phase 3 complete locally: five Firestore Emulator Rules tests pass.
- Phase 4 implemented repository-side: deterministic Firebase bootstrap/auth
  routing, email/Google/Apple authentication, password reset, missing-profile
  recovery, profile completion, and Create/Join Circle onboarding are present.
  Validators, error mapping, duplicate-submit guards, and automated routing/form
  tests are included.
- Phase 4 verification: `flutter analyze` is clean, 30 Flutter tests pass,
  Cloud Functions TypeScript compiles, and five Firestore Rules Emulator tests
  pass. Android debug and release APK builds succeed.
- External Phase 4 blocker: deploying `redeemCircleInvite` requires upgrading
  Firebase project `familyemergencyapp` to Blaze so Cloud Functions,
  Cloud Build, and Artifact Registry can be enabled. Apple Sign-In still needs
  Apple Developer/Xcode entitlements and Firebase provider configuration before
  iOS runtime testing.
- Local runtime note: the Pixel_7 AVD currently crashes before ADB connects
  (`QEMU2 CPU thread` hang and missing `opengl32sw`), so this Phase 4 pass could
  not perform Android emulator interaction despite successful APK compilation.

## Current migration rule

Relationship and authorization are different fields:

- `relationship`: Self, Father, Mother, Son, Daughter, and similar family labels.
- `circleRole`: owner, parent, adult, or child.

Never use a relationship value to authorize a Firestore operation.

## Firestore target structure

```text
users/{uid}
  notifications/{notificationId}
  checkIns/{localDate}

groups/{circleId}
  memberships/{uid}
  invites/{inviteId}
  devices/{deviceId}
  progressDaily/{uid_localDate}
  locationEvents/{eventId}
  emergencies/{emergencyId}
```

The existing `memberIds` and `roles` fields remain on the Circle document as an
authorization/query cache during migration. The corresponding membership
document is the detailed member record. Backend operations must update them
atomically.

The existing `groups/{circleId}/members` collection is temporary compatibility
for the current UI and must be removed after the registered-user invite flow is
live. The old `users/{uid}/members` migration has been retired.

## Ordered delivery

1. Baseline and automated checks.
2. Architecture and shared UI primitives.
3. Domain models, Firestore schema and Rules.
4. Auth bootstrap and onboarding.
5. Circle lifecycle and nested member details.
6. Secure invite, QR and join approval.
7. Profile restructuring and real security flows.
8. Device pairing and heartbeat.
9. Android aggregate screen-time collection.
10. Opt-in location activity.
11. Progress filters and reports.
12. FCM notifications and SOS delivery.
13. Local-time missed check-in automation.
14. Plan entitlements.
15. Full regression, physical-device validation and release APK.

## Quality gates

- Foundation: analyzer, unit tests and Firestore Rules emulator tests pass.
- Family: two real accounts complete create, invite, approve, join, leave and
  ownership-transfer flows.
- Device: a paired Android device sends real health, screen-time and consented
  location data.
- Safety: SOS and missed check-in reach only selected recipients and stop after
  acknowledgement.
- Release: entitlement checks, regression tests and signed APK pass.

## Verification commands

```powershell
flutter analyze
flutter test
Set-Location -LiteralPath rules-tests
pnpm test
```

The Rules suite runs against the local Firestore emulator and currently covers
member-only reads, manager-only Circle updates, atomic owner membership,
user-owned progress writes, and server-only notification creation.
