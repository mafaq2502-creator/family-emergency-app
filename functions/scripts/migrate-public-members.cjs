// Dry run by default. Apply before deploying the public-member reader/rules.
const admin = require('firebase-admin');
const project = process.argv.find(arg => arg.startsWith('--project='))?.slice(10);
if (!project) throw new Error('Pass --project=<Firebase project ID>; --apply writes the migration.');
admin.initializeApp({projectId: project});
const db = admin.firestore();
(async () => {
  let count = 0;
  const groups = await db.collection('groups').where('status', '==', 'active').get();
  for (const group of groups.docs) {
    const members = await group.ref.collection('memberships').get();
    for (const member of members.docs) {
      if (member.data().status !== 'active') continue;
      count++;
      if (!process.argv.includes('--apply')) continue;
      await db.runTransaction(async tx => {
        const [currentGroup, currentMember] = await Promise.all([tx.get(group.ref), tx.get(member.ref)]);
        const data = currentMember.data();
        if (currentGroup.data()?.status !== 'active' || !currentGroup.data()?.memberIds?.includes(member.id) || data?.status !== 'active') return;
        tx.set(group.ref.collection('publicMembers').doc(member.id), {
          userId: member.id, displayName: data.displayName ?? '', photoUrl: data.photoUrl ?? null,
          circleRole: data.circleRole, status: 'active', joinedAt: data.joinedAt ?? null,
        });
      });
    }
  }
  console.log(`${process.argv.includes('--apply') ? 'Migrated' : 'Would migrate'} ${count} public member records.`);
  await admin.app().delete();
})().catch(error => { console.error(error.message); process.exitCode = 1; });
