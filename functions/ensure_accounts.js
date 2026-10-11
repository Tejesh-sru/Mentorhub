process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = 'localhost:9099';
process.env.GCLOUD_PROJECT = 'menteeconnect-86997';

const { db, auth, Timestamp } = require('./src/init');

async function ensureUser({ uid, email, password, name, role, mentorCode, studentCode, batchId }) {
  let userRecord;
  try {
    userRecord = await auth.getUserByEmail(email);
    console.log(`Found existing user ${email} (${userRecord.uid})`);
    // Update password to ensure it matches
    await auth.updateUser(userRecord.uid, { password });
  } catch (err) {
    if (err.code === 'auth/user-not-found') {
      userRecord = await auth.createUser({
        uid,
        email,
        password,
        displayName: name,
        emailVerified: true,
      });
      console.log(`Created new user ${email} (${userRecord.uid})`);
    } else {
      throw err;
    }
  }

  // Set Custom Claims
  await auth.setCustomUserClaims(userRecord.uid, { role });
  console.log(`Set custom claim role=${role} on ${email}`);

  // Set user doc in Firestore
  const userDocRef = db.collection('users').doc(userRecord.uid);
  const userDocData = {
    uid: userRecord.uid,
    email,
    name,
    role,
    isActive: true,
    mustChangePassword: false,
    updatedAt: Timestamp.now(),
  };

  if (batchId) userDocData.batchId = batchId;
  if (mentorCode) userDocData.mentorCode = mentorCode;
  if (studentCode) userDocData.studentCode = studentCode;

  await userDocRef.set(userDocData, { merge: true });
  console.log(`Updated Firestore /users/${userRecord.uid}`);

  // If mentor, ensure /mentors doc
  if (role === 'MENTOR') {
    await db.collection('mentors').doc(userRecord.uid).set({
      uid: userRecord.uid,
      name,
      email,
      mentorCode: mentorCode || 'M001',
      batchId: batchId || 'default',
      isActive: true,
      studentCount: 5,
      updatedAt: Timestamp.now(),
    }, { merge: true });
  }

  // If student, ensure /students doc
  if (role === 'STUDENT') {
    await db.collection('students').doc(userRecord.uid).set({
      uid: userRecord.uid,
      name,
      email,
      studentCode: studentCode || '2403A51001',
      batchId: batchId || 'default',
      mentorId: 'mentor1_uid',
      isActive: true,
      leetcode: 'https://leetcode.com/u/student1_sru/',
      github: 'https://github.com/sru-student1',
      linkedin: 'https://linkedin.com/in/sru-student1',
      resume: 'https://drive.google.com/sru-resume',
      progress: {
        assigned: 12,
        completed: 10,
        pending: 2,
        awaitingReview: 1,
        overdue: 0,
        percentage: 83.3,
      },
      updatedAt: Timestamp.now(),
    }, { merge: true });
  }
}

async function main() {
  console.log('Ensuring all test accounts exist and have proper Firestore and Auth claims...');

  // Get first batch if available
  const batchesSnap = await db.collection('batches').limit(1).get();
  let batchId = 'default_batch';
  if (!batchesSnap.empty) {
    batchId = batchesSnap.docs[0].id;
    console.log(`Using existing batchId: ${batchId}`);
  } else {
    const newBatch = await db.collection('batches').add({
      name: 'CSE CSSP Batch 2026',
      academicYear: '2026-27',
      isActive: true,
      createdAt: Timestamp.now(),
    });
    batchId = newBatch.id;
    console.log(`Created default batchId: ${batchId}`);
  }

  // 1. Admin accounts (.internal AND .dev)
  await ensureUser({
    email: 'admin@mentorhub.internal',
    password: 'Admin@123',
    name: 'Chief Admin',
    role: 'ADMIN',
  });
  await ensureUser({
    email: 'admin@mentorhub.dev',
    password: 'Admin@12345',
    name: 'Chief Admin',
    role: 'ADMIN',
  });

  // 2. Mentor accounts (.internal AND .dev)
  await ensureUser({
    email: 'mentor1@mentorhub.internal',
    password: 'Mentor@123',
    name: 'K. Sai Krishna (Senior Mentor)',
    role: 'MENTOR',
    mentorCode: 'M001',
    batchId,
  });
  await ensureUser({
    email: '2303a51408@mentorhub.dev',
    password: 'Mentor@12345',
    name: 'DESINI CHARANVITHA',
    role: 'MENTOR',
    mentorCode: '2303A51408',
    batchId,
  });

  // 3. Student accounts (.internal AND .dev)
  await ensureUser({
    email: 'student1@mentorhub.internal',
    password: 'Student@123',
    name: 'V. Rahul (Junior Mentee)',
    role: 'STUDENT',
    studentCode: '2403A51001',
    batchId,
  });
  await ensureUser({
    email: '2405a41071@mentorhub.dev',
    password: 'Student@12345',
    name: 'DHARANE ANANYA',
    role: 'STUDENT',
    studentCode: '2405A41071',
    batchId,
  });

  console.log('Successfully provisioned all accounts!');
  process.exit(0);
}

main().catch((err) => {
  console.error('Error in ensure_accounts:', err);
  process.exit(1);
});
