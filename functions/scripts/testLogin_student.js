const { initializeApp } = require('firebase/app');
const { getAuth, connectAuthEmulator, signInWithEmailAndPassword } = require('firebase/auth');

const app = initializeApp({ projectId: 'menteeconnect-86997', apiKey: 'fake-api-key' });
const auth = getAuth(app);
connectAuthEmulator(auth, 'http://127.0.0.1:9099');

signInWithEmailAndPassword(auth, '2403a51015@mentorhub.dev', 'Student@12345')
  .then(r => console.log('SUCCESS', r.user.uid))
  .catch(e => console.error('ERROR:', e.code, e.message));
