// Usage: node scripts/createAdmin.js admin@example.com 'StrongPass123' 'Admin Name'
// Talks to the emulators if FIREBASE_AUTH_EMULATOR_HOST / FIRESTORE_EMULATOR_HOST are set, otherwise to the real
// project (needs GOOGLE_APPLICATION_CREDENTIALS pointing at a service-account key and GCLOUD_PROJECT).
const { createAdmin } = require('../src/services/users');

const [email, password, name] = process.argv.slice(2);
if (!email || !password) { console.error('Usage: node scripts/createAdmin.js <email> <password> [name]'); process.exit(1); }
createAdmin({ email, password, name })
  .then((r) => { console.log('Admin created:', r.uid); process.exit(0); })
  .catch((e) => { console.error(e.message); process.exit(1); });
