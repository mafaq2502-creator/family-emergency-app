# Safety Users and persistent navigation deployment

This change is source-only. No APK/AAB, production deployment, production migration,
real email send, or real-device FCM test has been performed.

## Model and authority

- `users/{ownerId}/safetyUsers/{invitationId}` is private owner contact data. It is
  separate from Circle membership, even after acceptance. Only the owner can read;
  all changes use authenticated callables.
- `safetyInvites/{randomToken}` binds a single personal invitation to a normalized
  email and, where known, the Firebase Auth UID. A verified matching email is
  mandatory for acceptance. Connected and unexpired pending rows count toward the
  Free five-user limit. Decline/revoke/remove release capacity. Expired records do
  not reserve capacity; the UI expires them with a timer.
- Direct Circle invitations reuse `circleInvites`, the existing 24-character token,
  Circle reservation accounting and Free one-owned/one-joined/three-person limits.
  Only connected Added Users can be selected. A server eligibility query explains
  full/already-member/pending/target-plan exclusions; the mutation rechecks them.
- `invitationDeliveries/{token}` represents channels of the same logical request.
  `safetyEvents/{eventId}` is a server-private notification outbox. Deterministic
  removal event IDs prevent duplicate logical events/history.
- `groups/{circleId}/publicMembers/{uid}` contains only user identity, display name,
  avatar, role/status and join timestamp. Other members cannot read the private
  membership documents or owner-specific Added User details. Owners retain member
  removal controls through a limited Circle-member screen.

## Removal

`removeSafetyUser` checks ownership and commits contact/preferences deletion,
related owner-side historical rows, personal invite revocation, applicable owned
Circle membership/device/request cleanup, profile references and removal events
in one transaction. Every affected Circle is owned by the caller. Third-party
Circles, the target's Auth account and global profile are preserved. Pending direct
and reserved Share/QR invitations from the owner to this target are revoked;
untargeted Share/QR tokens are not revoked because they have no recipient identity.
Re-adding creates a fresh token with Emergency ON and all advanced preferences OFF.
Transactions above the guarded write budget fail before writes, rather than
silently performing partial cleanup.

Notification delivery follows the authoritative commit. Push failure never
restores the relationship. History records exclude private outbox paths. Queued
monitoring events recheck the relationship, category and plan before dispatch.
An already dispatched external push cannot be recalled by a later removal.

## Email configuration

Configure these server environment values through the deployment environment:

- `INVITATION_EMAIL_ENDPOINT`: HTTPS transactional-email adapter endpoint.
- `INVITATION_EMAIL_TOKEN`: server-only bearer credential; keep out of source,
  Flutter, logs and committed `.env` files. Provision through your secret system.
- `INVITATION_LINK_BASE`: HTTPS app-link endpoint, normally
  `https://familyemergencyapp.web.app/join`; it must match the app's configured host.

The adapter accepts JSON `{to, subject, text}` and must honor the `Idempotency-Key`
header. A successful HTTP response means provider-accepted, not confirmed inbox
arrival. Missing configuration is explicitly recorded as `configuration-required`;
failures are recorded as `failed`. The client reports a queued request, never fake
email delivery. Operators must resolve configuration/failures before retrying
external delivery. No SMTP credentials are embedded in the app.

An account with no active notification-enabled FCM device still has its incoming
request. Email and push refer to the same token. Unknown email identities remain
pending and become readable after signing into the verified matching email.
The hosting page supports personal and Circle links; configure the real Play Store
application ID before publishing (the existing placeholder is not a released app).

## Required rollout order

1. Deploy callable functions, public member projection triggers and new indexes.
2. Backfill existing active memberships with
   `node functions/scripts/migrate-public-members.cjs --project=YOUR_PROJECT`.
   This is a dry run. Add `--apply` only for the explicitly authorized migration.
   The script rechecks current group/membership state transactionally and copies no
   private contact fields.
3. Publish the updated Firestore rules and matching app version together. The new
   reader expects `publicMembers`; older app versions reading private membership
   lists must be upgraded. Do not publish rules before the projection/backfill.
4. Deploy the invitation hosting page with actual app installation configuration.
5. Configure transactional email and verify on real devices: email-only unknown
   recipient, email + FCM existing recipient, foreground/background/terminated tap,
   removal history and separate Circle removal events.

None of these production steps have been run in this task. Keep the existing
project deployment instructions for normal Firebase environment setup.

## Notifications and current platform capabilities

Per-user preferences are independent of Profile notification preferences.
Emergency is Free; Battery, Screen Time, Offline, Check-In and Location are Premium.
The backend rechecks entitlement, so a client cannot enable paid categories.

The shared dispatch boundary is wired to SOS, available low-battery changes,
four-hour Screen Time crossings, recorded location events, check-in records and a
15-minute offline evaluator using the existing 60-minute offline boundary. Alerts
are generated only when source data exists. Device battery collection and location
collection still depend on the platform/consent functionality; no data is fabricated.
Check-In here reports actual check-ins; Phase 13 missed-deadline evaluation remains
part of the existing roadmap. Scheduling requires Cloud Scheduler deployment.

## Explicitly isolated Free/Premium tests

`ENABLE_TEST_ENTITLEMENTS` is OFF by default. The UI is compiled only in debug mode
with `--dart-define=ENABLE_TEST_ENTITLEMENTS=true`. That flag initializes the app
against `demo-alivecircle` and routes Auth, Firestore and Functions to local emulators;
`FIREBASE_EMULATOR_HOST` defaults to Android emulator host `10.0.2.2`.

Start local emulators with server environment `ENABLE_TEST_ENTITLEMENTS=true`.
Only the verified test account `nihalafaq@gmail.com` can use FREE TEST MODE and
PREMIUM TEST MODE. `setTestPlan` also requires `FUNCTIONS_EMULATOR=true`; deployed
production Functions reject it even if a client fabricates a call. Real production
subscription fields remain server-owned. Disable the development flag for normal
runs; no test account receives an uncontrolled production Premium entitlement.

## Tests

- `flutter analyze --no-pub`
- `flutter test --no-pub`
- `node functions/node_modules/typescript/bin/tsc --noEmit -p functions`
- `rules-tests` package `test` includes safety privacy rules.
- `test:safety` runs callable integration tests against demo Auth/Firestore/Functions.
  Compile the Functions TypeScript for the emulator before that command.
- Set the emulator-only environment flag above to exercise both allowed test modes.

Real provider delivery and production deployment must not be inferred from emulator
results. Billing UI switches $2.99/month and $28.70/year (20% off); purchase and
subscription management explicitly remain unconnected until Phase 14 billing.
