// Usage: node scripts/createSuperAdmin.js superadmin@example.com 'StrongPass123' 'Super Admin Name'
// Talks to the emulators if FIREBASE_AUTH_EMULATOR_HOST / FIRESTORE_EMULATOR_HOST are set, otherwise to the real
// project (needs GOOGLE_APPLICATION_CREDENTIALS pointing at a service-account key and GCLOUD_PROJECT).
const { auth, db, Timestamp } = require('../src/init');

const [email, password, name = 'Super Administrator'] = process.argv.slice(2);
if (!email || !password) {
  console.error('Usage: node scripts/createSuperAdmin.js <email> <password> [name]');
  process.exit(1);
}

async function main() {
  const user = await auth.createUser({ email, password, displayName: name });
  await auth.setCustomUserClaims(user.uid, { role: 'SUPER_ADMIN' });
  await db.doc(`users/${user.uid}`).set({
    email,
    role: 'SUPER_ADMIN',
    name,
    isActive: true,
    mustChangePassword: false,
    batchId: null,
    createdAt: Timestamp.now(),
  });
  console.log('Super Admin created successfully:', user.uid);
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
