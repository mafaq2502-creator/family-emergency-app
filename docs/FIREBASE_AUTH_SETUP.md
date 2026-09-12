# Firebase Authentication setup

Firebase project: `familyemergencyapp`

## Email verification

Email verification is owned by Firebase Authentication. The app reads
`FirebaseAuth.currentUser.emailVerified`; it deliberately does not keep a
second Firestore boolean that could become stale or be changed by the client.

For an email/password user, use the verification link sent to the user's inbox.
The app now reloads Firebase automatically while the verification screen is
visible and when the app resumes. **Next** also performs a fresh Firebase check.

## Google Sign-In Android configuration

The current `android/app/google-services.json` belongs to the correct project
and package but contains no OAuth client entries. Enabling the Google provider
and choosing a support email does not add the Android signing certificate to an
already-downloaded file.

In Firebase Console:

1. Open **Project settings → General → Your apps**.
2. Select Android app `com.example.family_emergency_app`.
3. Add these current testing-certificate fingerprints:

   - SHA-1: `76:53:49:7B:BB:0B:DE:0C:F6:E7:C3:8B:6F:0B:5E:FB:70:5A:A6:79`
   - SHA-256: `69:01:61:DE:5E:47:79:F2:DE:93:7A:36:6B:AE:F1:F9:99:6E:DE:1E:80:23:78:C6:72:EB:E5:77:3B:70:4B:6D`

4. Save, then download the new `google-services.json`.
5. Replace `android/app/google-services.json` with the downloaded file.
6. Rebuild the APK. Confirm the new file contains OAuth client entries before
   testing Google Sign-In.

The current release-testing APK uses the debug signing certificate. Before a
Play Store release, configure a private release/upload key, add its SHA-1 and
SHA-256 to Firebase, and download the configuration again.
