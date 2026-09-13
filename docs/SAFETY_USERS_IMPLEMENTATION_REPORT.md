# Safety Users implementation report

Source implementation is finished and local verification passes. Production activation, external provider configuration and
physical-device acceptance remain separate. No APK or AAB was generated.

1. **Files modified:** backend/rules/indexes; authenticated navigation shell;
   Family tabs; Safety Users service and screens; Circle detail/settings/invitation
   screens; notification navigation; auth invitation-link handling; shared dialog
   and avatar widgets; Plans; test bootstrap; hosting invitation page; regression
   tests; public-member migration script. The file inventory below lists paths.
2. **Persistent navigation:** one authenticated navigator renders child routes
   above one bottom bar. Section selection persists on detail/settings screens;
   Android Back pops child routes before the shell. Auth/onboarding stay outside.
3. **Family architecture:** Circles and Users are internal Family tabs; existing
   Owned/Joined Circle filters, create, join, settings and invites remain.
4. **Users List:** live owner-private list with name/avatar, Pending/Connected
   status, active/reserved count and Add New User action.
5. **Requests:** live incoming personal requests with sender/avatar and Accept or
   Cancel (decline), using the same request identity as delivery channels.
6. **Personal invitations:** separate random-token lifecycle, normalized email,
   optional known Auth UID, expiry and backend-authorized state transitions.
7. **Email status:** backend HTTP adapter/template and delivery status implemented.
   No transactional provider is configured or falsely reported as delivered.
8. **User push/in-app:** one invitation outbox references the same token; registered
   notification-enabled devices receive an FCM attempt and history uses one ID.
9. **Accept/Decline:** verified matching email and intended UID are checked by the
   backend; acceptance creates Connected state, decline releases the row/slot.
10. **Free five-user limit:** active relationships plus unexpired pending
    reservations are atomically counted; concurrent sixth invites are rejected.
11. **User Detail:** selected target contact metadata and status, not the owner's
    Profile settings, with a separate per-user preferences child screen.
12. **Owner-only authorization:** Firestore denies other users' private rows and
    client writes; UI also refuses mismatched-owner detail/preferences.
13. **Remove icon:** top action area, owner-only, matching Circle trash styling.
14. **Confirmation:** explains contact/preferences and owned-Circle removal;
    Cancel/X perform no mutation and Remove waits for the backend.
15. **Relationship cleanup:** transaction deletes the selected owner-target row.
16. **Private cleanup:** related historical owner-target contact rows are removed;
    target global account/profile and other owners' relationships remain intact.
17. **Preferences cleanup:** deleting relationship documents removes settings;
    queued monitoring dispatch rechecks active relationship and entitlement.
18. **Circle removal:** removes target memberships, embedded IDs, SOS recipients,
    public member row, linked Circle devices and applicable pending requests.
19. **Affected Circles:** all active Circles owned by the deleting owner where the
    target is a member; pending owned-Circle requests/invites are also cancelled.
20. **Third-party Circles:** not modified. The backend derives ownership from each
    Circle document and never accepts a client-provided list of Circles to delete.
21. **User Removal event:** deterministic target-visible history and FCM dispatch
    after commit, with delivery failure/no-device status recorded separately.
22. **Circle Removal events:** distinct deterministic events per affected Circle;
    no relationship restoration on external delivery failure.
23. **Target refresh:** live group query and membership updates remove inaccessible
    Circles; stale detail routes are dismissed and local invalidation filters
    suppress cached rows until the server reconciles membership.
24. **Slot release:** removal, decline, revocation and expiry release current
    capacity; lifetime invitation history is not counted.
25. **Re-invite:** fresh random invitation lifecycle and default preferences;
    historical preferences are not silently restored.
26. **Preferences:** independent owner-target Emergency, Battery, Screen Time,
    Device Offline, Check-In and Location categories, separate from global Profile.
27. **Defaults:** accepted relationships initialize Emergency ON, all others OFF.
28. **Premium gates:** UI and callable backend both enforce paid advanced settings;
    dispatch rechecks entitlement. Source signals are wired where available.
29. **Circle Invite User:** server-reviewed eligible connected Added Users; full,
    existing-member, active-request and joined-plan exclusions are explained.
30. **Incoming Circle requests:** available from Join Circle, with recipient-bound
    Accept/Decline and atomic membership/capacity/plan checks.
31. **Popup X:** shared close control is aligned top-right beside the entire title
    area, including dialogs with icons; temporary edits are discarded on close.
32. **Test plans:** explicit FREE/PREMIUM TEST MODE for the allowlisted verified
    account, debug UI plus local demo Firebase emulator checks on the server.
33. **Monthly/Yearly:** $2.99/month or $28.70/year with 20% discount, approximate
    monthly equivalent and changed CTA. Real purchase billing is not fabricated.
34. **Stale Circle fix:** list invalidation, server reconciliation, live membership
    filtering and exit from deleted/inaccessible detail routes.
35. **Flutter tests:** 313/313 passed, including all previous tests and new persistent navigation, pricing, private detail, confirmation and per-user settings checks.
36. **Firestore/callable tests:** 63/63 passed across existing rules/lifecycle and new safety privacy, atomic capacity, removal, invitation, delivery-history, trigger and emulator test-plan checks.
37. **Analyzer:** `flutter analyze --no-pub` reports no issues; Functions TypeScript compilation passes; `git diff --check` has no whitespace errors.
38. **External email:** endpoint, token and matching app-link base must be configured;
    hosting must use the real published application ID. Real email/FCM acceptance
    needs devices/provider configuration and has not been claimed as tested.
39. **Production test configuration:** leave ENABLE_TEST_ENTITLEMENTS disabled.
    Release builds omit the controls and deployed Functions reject emulator-only
    overrides. Follow SAFETY_USERS_DEPLOYMENT.md for rollout and migration.

## Operational limits

- Firestore write-budget guard rejects oversized removal transactions without
  partial cleanup; such exceptional datasets need administrator-assisted cleanup.
- Source notification handlers consume real data only. Battery telemetry and
  consent-based location still depend on existing/platform collection support.
  Check-In alerts report actual check-ins; missed-deadline automation remains
  Phase 13. Offline evaluation requires deployed Cloud Scheduler.
- Provider-accepted is not proof of inbox/device delivery. A push already dispatched
  before relationship removal cannot be recalled.
- Existing Circles need the public-member backfill before the new private-read
  rules and app version are rolled out. Older clients must be upgraded together.
- Emulator runtime uses installed Node 24; Functions deployment target remains
  Node 20. TypeScript targets ES2022 and uses supported Node 20 APIs.

## File inventory

- firestore.rules
- firestore.indexes.json
- functions/src/index.ts
- functions/src/safety-policy.ts
- functions/scripts/migrate-public-members.cjs
- hosting/join.html
- lib/main.dart
- lib/app/notification_navigation.dart
- lib/core/widgets/authenticated_navigation_shell.dart
- lib/core/widgets/light_ui.dart
- lib/features/auth/presentation/auth_gate.dart
- lib/features/shell/presentation/family_shell.dart
- lib/features/shell/presentation/tabs/members_tab.dart
- lib/features/shell/presentation/tabs/plan_tab.dart
- lib/features/members/presentation/safety_users_screen.dart
- lib/features/members/presentation/circle_member_detail_screen.dart
- lib/features/groups/presentation/group_members_screen.dart
- lib/features/groups/presentation/group_settings_screen.dart
- lib/features/groups/presentation/join_circle_screen.dart
- lib/features/groups/presentation/share_circle_screen.dart
- lib/models/notification_settings.dart
- lib/services/safety_user_service.dart
- lib/services/group_service.dart
- rules-tests/package.json
- rules-tests/safety-users.rules.test.cjs
- rules-tests/safety-users.integration.test.cjs
- test/persistent_safety_navigation_test.dart
- test/safety_users_ui_test.dart
- docs/SAFETY_USERS_DEPLOYMENT.md
- docs/SAFETY_USERS_IMPLEMENTATION_REPORT.md
- CODEX_HANDOFF.md
