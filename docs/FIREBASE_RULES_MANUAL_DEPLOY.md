# Firebase Firestore rules — manual deployment

Use the Firebase project `familyemergencyapp`.

1. Open Firebase Console.
2. Select **familyemergencyapp**.
3. Open **Firestore Database → Rules**.
4. Replace the complete editor contents with the complete contents of the
   repository-root `firestore.rules` file. Do not paste only the newly added
   functions: the lifecycle checks depend on helper functions elsewhere in that
   file.
5. Click **Publish**.
6. Wait for the successful publication message before testing Circle deletion.

No Firestore index change is required for this task. The new notification
cleanup query uses Firestore's automatic single-field `groupId` index.

After publishing, test with a disposable Circle:

- confirm a non-owner cannot delete it;
- cancel once and confirm nothing changes;
- confirm deletion once as owner;
- confirm the Circle disappears immediately and the app returns to Family;
- confirm its pending invite/request is inactive;
- confirm unrelated global device records and other-Circle notifications remain.

Publishing these rules enables the Spark-compatible client deletion path. It
does not deploy Cloud Functions or enable automatic FCM event delivery.
