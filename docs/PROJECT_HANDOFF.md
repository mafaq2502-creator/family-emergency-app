# Family Emergency — Project Handoff Reference

> Read this file first in any new chat. It records the app purpose, current code state, decisions made with the product owner, technical setup, and the next safe work items.

## 1. Product purpose

**Family Emergency** is a family-safety Flutter app. A person creates an account, maintains a family member list, can trigger an emergency action, and will eventually use the app for consent-based family safety alerts.

The visual direction is a calm **Emerald & Neutral** design:

- Light mode: off-white page, white rounded cards, navy headings, emerald primary actions.
- Dark mode: navy-black page and card surfaces, white text, emerald selected/online states, and red only for SOS/destructive actions.
- The supplied UI references used phone-sized, highly rounded cards and a raised circular Home item in the bottom navigation.
- The visual source of truth for colors is [`UI_COLOR_PALETTE.md`](UI_COLOR_PALETTE.md).

## 2. Tech stack and attached services

| Area | Current choice | Notes |
| --- | --- | --- |
| App framework | Flutter / Dart | SDK constraint: `^3.13.2` |
| UI | Material widgets + Material icons | No custom avatar/image assets have been added yet. |
| Typography | Manrope via `google_fonts` | Applied globally through the light and dark `ThemeData` text themes. |
| Authentication | Firebase Authentication | Email/password, password-reset email, Google, and Apple client flows are coded. Firebase providers/platform configuration is still required. |
| Data | Cloud Firestore | User profile document is read and saved at `users/{uid}`. |
| Firebase bootstrap | `firebase_core` | `Firebase.initializeApp()` runs before `runApp()`. |
| Country phone selector | `country_picker` | Searchable country list, device-locale suggestion, manual override. |
| Device time zone | `flutter_timezone` | Captures an IANA time-zone identifier for daily check-ins. |
| Android Firebase config | `android/app/google-services.json` | Present in the repository. |
| Platforms | Android, iOS, web, Windows, macOS, Linux scaffolds | Android emulator has been used during development. |

### Current dependencies

```yaml
firebase_core: ^4.14.0
firebase_auth: ^6.6.1
cloud_firestore: ^6.9.0
google_fonts: ^6.3.3
country_picker: ^2.0.28
flutter_timezone: ^5.1.0
cupertino_icons: ^1.0.8
```

### Not connected yet

- Firebase Storage / profile photo upload
- Firebase Console enablement and platform configuration for Google/Apple providers
- Firebase Auth password update + re-authentication connection
- Secure server-side password history enforcement
- Email OTP delivery and verification for account deletion
- Actual Firebase Auth/Firestore account deletion
- Device location services or map provider
- Push notifications, local notifications, SMS, phone calling, or background jobs
- Battery/offline tracking
- Payments/subscriptions
- A server/backend for scheduled daily check-ins

### Member CRUD and social sign-in setup

- Member CRUD code uses `users/{ownerUid}/members/{memberId}` in Cloud Firestore through `FamilyMemberService`.
- Before testing it, enable Firestore and deploy rules that allow an authenticated owner to manage only their own `members` subcollection.
- Enable Google and Apple in Firebase Authentication. Google needs Android/iOS/web client configuration; Apple needs an Apple Developer Team, Service ID, return URL, and iOS capability configuration. The app code alone cannot enable either provider.

Do **not** claim any of the above work as complete until it is actually added, configured, and tested.

### Required Firebase Console action before profile/member persistence can work

Android runtime logs on the development emulator confirm that Firebase Authentication initializes successfully. Cloud Firestore is currently **disabled** for the Firebase/Google Cloud project `familyemergencyapp`, so profile reads/writes receive `PERMISSION_DENIED` and the client operates offline.

An authorized project owner must enable the Cloud Firestore API / create the Firestore database in the Firebase Console for that project, wait for propagation, then configure and deploy suitable Firestore Security Rules. This cannot be fixed safely from the Flutter client code alone.

## 3. Important source files

| File | Responsibility |
| --- | --- |
| [`lib/main.dart`](../lib/main.dart) | Firebase bootstrap only. |
| [`lib/app/family_emergency_app.dart`](../lib/app/family_emergency_app.dart) | App root, themes, and initial route. |
| [`lib/features/auth/presentation/login_screen.dart`](../lib/features/auth/presentation/login_screen.dart) | Email/password Login UI and Firebase sign-in. |
| [`lib/features/auth/presentation/signup_screen.dart`](../lib/features/auth/presentation/signup_screen.dart) | Sign-up UI, validation, Firebase account creation, initial Firestore user document. |
| [`lib/features/profile/presentation/profile_settings_screen.dart`](../lib/features/profile/presentation/profile_settings_screen.dart) | In-app Profile Settings, Update Password UI, and multi-step Delete Account demo flow. |
| [`lib/features/shell/presentation/family_shell.dart`](../lib/features/shell/presentation/family_shell.dart) | Shared family-shell state, navigation, profile persistence, check-in and SOS actions. |
| [`docs/UI_COLOR_PALETTE.md`](UI_COLOR_PALETTE.md) | Reusable light/dark color tokens and combinations. |
| [`Family_Emergency_App_Product_Plan.docx`](../Family_Emergency_App_Product_Plan.docx) | Earlier product-planning document; preserve it. |
| [`create_product_document.py`](../create_product_document.py) | Script previously used to create the DOCX; preserve it. |

## 3.1 Current code structure

```text
lib/
  main.dart                                # Firebase bootstrap only
  app/family_emergency_app.dart            # MaterialApp, global theme, initial route
  core/theme/                              # App colors and theme-mode controller
  core/widgets/                            # Shared card and primary-button UI components
  models/                                  # UserProfile, FamilyMember, NotificationSettings
  services/                                # Auth, profile/check-in, notification persistence boundaries
  features/
    auth/presentation/                     # Login and Sign Up
    notifications/presentation/            # Notification Settings
    profile/presentation/                  # Profile Settings / account-security demo
    shell/presentation/
      family_shell.dart                    # Authenticated shell, shared state and navigation
      tabs/                                # Home, Members, Location, Plan and Profile widgets
```

`main.dart` is intentionally minimal. Each tab now lives in its own presentation file, while `FamilyShell` owns the temporary shared in-memory state and callbacks. Members use the `FamilyMember` model, and shared core widgets avoid repeated card/button styling. The next data-layer refactor should add a dedicated family-member repository backed by Firestore.

## 4. Current navigation and screens

The navigation order in code is:

1. **Location** — index `1`
2. **Members** — index `0`
3. **Home** — index `2`, raised circular center action
4. **Plan** — index `3`
5. **Profile** — index `4`

`HomeScreen` currently initializes `_currentIndex` to `0`, so after Login/Sign Up it opens the **Members** tab first. If product behavior should open Home first, change this to `2` and test it.

### Login

Implemented:

- Reference-style decorative background, family mark, fields, emerald Login button, Google-style outlined button, and Sign Up link.
- Email/password validation.
- Firebase `signInWithEmailAndPassword`.
- Error SnackBar for invalid credentials.
- Dark-aware page/field surfaces.

Partial / pending:

- Remember me checkbox is UI only.
- Forgot Password action is empty.
- Google button is UI only; no Google Sign-In integration.

### Sign Up

Implemented:

- Reference-style five-field layout: full name, email, phone, password, confirm password.
- Phone field auto-suggests the device locale country and provides a searchable manual country list. It saves `phoneCountryIso`, `phoneCountryCode`, and normalized E.164 `phone` value.
- Terms checkbox must be accepted before submission.
- Password confirmation and basic validation.
- Firebase account creation, display name update, and Firestore user document creation.
- Dark-aware page/field surfaces.

Initial Firestore document fields:

```text
uid, name, email, phone, phoneCountryIso, phoneCountryCode,
role: "Self", isFamilyOwner: true, notificationSettings, createdAt
```

Product decision: the supplied design does not include a relationship field at sign-up. It is initialized as `Self`, and can be changed in Profile.

### Home

Implemented UI:

- Greeting with the saved profile name when available.
- “Your family is safe” label and family icon.
- Two-column member status cards for up to four items: online state, battery label, and location label.
- Compact red Emergency button.
- Daily **“I'm Alive”** check-in button. A successful press stores `lastDailyCheckInAt` in `users/{uid}` and marks the current local calendar date as checked in.
- Raised Home navigation item.
- Light and dark card treatments.

Functional state:

- Default members are in an in-memory `familyMembers` list: Father, Mother, Brother, Sister.
- Avatars are Material-icon placeholders. The reference illustrated avatar image assets have not been supplied or added.
- Member status, battery percentage, and `Lahore, PK` are display placeholders, not device data.
- SOS starts a local countdown/alert flow only; it does not notify anyone externally.
- The check-in is one per local calendar day (12:00 AM through 11:59 PM). It resets automatically when the date changes. It requires Firestore to be enabled for persistence.

### Members

Implemented UI:

- Heading/subtitle.
- Full-width emerald Add Member button.
- Compact cards with avatar placeholder, online dot, name, phone, relationship, options icon, and delete icon.

Functional state:

- Add Member opens an in-memory dialog requesting name, email, relation, and access preferences.
- Added members are not saved to Firestore.
- Delete removes a member only from the in-memory list.
- Three-dot options currently shows a “coming soon” SnackBar.
- Default phone numbers are UI placeholders unless member data includes a phone.

### Location

Implemented UI:

- Reference-style `Live Location` heading and illustrated empty state.

Current behavior:

- It deliberately says that the map will be available soon.
- No real location permission, device sharing, map SDK, or tracking is present.

### Plan

Implemented UI:

- Side-by-side Free and Premium cards with price, feature list, Current Plan state, and Upgrade button.

Current behavior:

- Free/Premium pricing and feature text are UI-only.
- Upgrade button only shows a “coming soon” SnackBar.
- No payments, subscription state, entitlement enforcement, or backend exists.

### Profile

Implemented:

- Reference-style compact profile information cards.
- **Name** is editable.
- **Relationship** is editable with a dropdown, including `Self`.
- **Email** and **phone** are displayed locked/read-only.
- Save button appears in the Profile header and is enabled only when name or relationship changed.
- Saving updates Firestore `users/{uid}`. Firebase Auth display-name synchronization remains pending.
- Navigating back with unsaved profile edits prompts the user to Save, Discard, or Keep Editing.
- Theme selector supports System, Light, and Dark; system is the initial default.
- **Notification Settings** opens a dedicated settings screen. The user can control missed check-in, emergency, battery, device-offline, and location-sharing preferences.
- The family-wide missed-check-in notification toggle is enabled only for `isFamilyOwner: true` accounts; invited members should be stored with `isFamilyOwner: false`.
- **Profile Settings** opens an Account Security page with Update Password and Delete Account flows.
- Update Password currently validates current/new/confirm inputs, requires a new password different from the entered current password, and shows a demo success result. It does **not** yet call Firebase Auth.
- Delete Account currently provides the requested UI flow: registered email confirmation → code entry → final destructive confirmation. The local demo code is `123456`; it does **not** send email or delete the account.
- Logout works through Firebase Auth sign-out.

Current limitation:

- Profile photo upload is not implemented. Previous UI only displayed a placeholder message; no Storage package or picker is connected.

## 5. Design system

Use the saved palette instead of new arbitrary colors. The key code tokens are currently in `lib/main.dart`:

```dart
kEmerald           // #10B981 primary/selected/online
kNavy              // #112A55 light headings
kEmergency         // #EF4444 SOS and destructive action
kDarkBackground    // #07131D
kDarkSurface       // #10212D navigation/surface
kDarkCard          // #132431 cards
kDarkCardElevated  // #182C3A elevated surface
kDarkMuted         // #AFC0CF muted dark text
```

Keep the same screen hierarchy and components in light and dark mode; alter colors and contrast, not the layout.

## 6. Product decisions already discussed

### Plans (not implemented)

- Free plan: owner can add up to **2** other members.
- Premium: owner can add up to **10** other members.
- Extra seats beyond the included limit should be billed to the family-circle owner.
- Premium concepts discussed: consented location access, device battery status, low-battery alert around 5%, offline/device-off alert, plus emergency notification/call behavior.

### Family-circle billing and consent (not implemented)

- A paid plan should belong to a **Family Circle owner**, not automatically make every invited person a paying subscriber.
- Every member should use their own account and explicitly consent to sharing location/device information.
- Entitlements should be checked on the family circle/server side, not trusted from the client UI.

### Daily check-in

Implemented client behavior:

- Home has an **“I'm Alive”** button.
- The button saves `lastDailyCheckInAt`, `lastDailyCheckInTimeZone`, and `lastDailyCheckInLocalDate` in the signed-in user's Firestore document.
- It shows “Checked in today” after success and becomes eligible again on the next local calendar date.

Still not implemented:

- **Check-in deadline:** the daily cycle is each member's own local **10:00 AM through 9:59 AM** the following day. A missed-check-in notification is eligible only after a full cycle passes without the member pressing **“I'm Alive.”**
- **Time zones:** save the check-in's UTC timestamp plus the member's IANA device time zone (for example, `Asia/Karachi`). A trusted backend must calculate the 10:00 AM deadline in that member's local time; never use the family owner's time zone for every person.
- **Notifications:** at the missed 10:00 AM deadline, notify only family-circle members who opted in to receive missed-check-in alerts. The person who missed check-in should not be falsely marked unsafe; the message should say that a check-in was missed and encourage contact.
- **Backend requirement:** this needs server scheduling (for example, Firebase Cloud Functions/Cloud Scheduler), Firebase Cloud Messaging, notification permissions, and notification preference storage. It cannot be reliably delivered by a closed mobile app alone.
- **Phone number UX:** phone input should auto-suggest the country using device locale/SIM when available, but always provide a searchable manual country list with flag, calling code, and validation. Never rely only on IP geolocation. Store country ISO code and normalized E.164 phone number.
- This needs backend scheduling, time-zone rules, notification permissions, and a privacy policy before implementation.

## 7. Known technical debt / caution list

1. `lib/main.dart` is currently a large, single file. Before adding real tracking/payments, split into models, services, repositories, and feature screens.
2. The current member list and device-status values are local placeholders. Do not present them as production tracking.
3. The current Firebase structure only persists the signed-in user’s profile, not family circles or members.
4. Firestore Security Rules are not documented here. Review and deploy least-privilege rules before real user use.
5. The supplied screen references are external images, not committed design assets. Do not assume avatar/logo/map image files exist in the project.
6. `flutter analyze` was last run after cleanup and returned **No issues found**.
7. Profile leave protection uses `PopScope`; retain this modern API when editing navigation.

## 8. Suggested next implementation order

1. Run the app on emulator and visually compare each screen at phone size; make spacing/asset corrections from user feedback.
2. Split `main.dart` into feature files and add models (`UserProfile`, `FamilyCircle`, `FamilyMember`).
3. Persist family members and invitations in Firestore with correct Security Rules.
4. Implement actual profile photo selection + Firebase Storage, only after adding privacy/storage rules.
5. Implement Forgot Password and Google Sign-In if required.
6. Build a real subscription model using a server and a payment provider; do not enforce paid features only in the Flutter client.
7. Add location, notifications, battery/offline monitoring only with per-member consent, platform permissions, background execution design, and policy/legal review.
8. Add tests for authentication routing, profile dirty-state save/discard, and Firestore serialization.

## 9. Local development commands

From the project root:

```powershell
C:\Users\Farhan\develop\flutter\bin\flutter.bat pub get
C:\Users\Farhan\develop\flutter\bin\flutter.bat analyze
C:\Users\Farhan\develop\flutter\bin\flutter.bat run
```

Android emulator used previously: `Pixel_7` (typically appears as `emulator-5554` through ADB).

## 10. Definition of done for future work

For each request:

1. Implement the requested behavior and its UI in both supported themes when applicable.
2. Run `flutter analyze` and resolve all new errors.
3. Run on emulator when visual or platform behavior changed.
4. Update this handoff document whenever product behavior, architecture, Firebase schema, or completion status changes.
5. Clearly distinguish shipped behavior from placeholders and planned features.
