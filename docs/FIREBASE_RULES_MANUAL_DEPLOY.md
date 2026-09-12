# Firebase backend deployment

Use Firebase project `familyemergencyapp`.

The current Circle lifecycle requires all three repository backend artifacts:

- `functions/src/index.ts`
- `firestore.rules`
- `firestore.indexes.json`

Deploy them together after reviewing the local changes. Deploying only the rules
will leave Circle create/delete/invite/join actions unavailable because clients
are intentionally blocked from bypassing the callable transactions.

```powershell
Set-Location -LiteralPath 'D:\My Projects\family_emergency_app\functions'
npm run build
Set-Location -LiteralPath 'D:\My Projects\family_emergency_app'
firebase deploy --project familyemergencyapp --only functions,firestore:rules,firestore:indexes
```

The user has instructed Codex not to run any build command until they request it
in a separate prompt. These commands are documentation only and were not run in
the current task.

After deployment, use disposable accounts and Circles to verify:

1. A non-owner cannot delete a Circle; its owner can delete it once without the
   Circle reappearing or showing a permission error.
2. A Free account cannot own more than one active Circle, and can create another
   after deleting the first.
3. A Free account cannot join more than one additional Circle.
4. A Free Circle stops at owner plus two people, including active invitation
   reservations. Revoke, cancel, reject, and expiry release capacity.
5. One link and its QR code resolve the same token. Approval consumes it and a
   second use is rejected.
6. SOS reaches only the selected current members, appears in notification
   history, and opens the emergency detail destination when tapped.
