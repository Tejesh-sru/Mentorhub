const fs = require('fs');
const admin = require('../node_modules/firebase-admin');

process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';

admin.initializeApp({ projectId: 'menteeconnect-86997' });
const db = admin.firestore();
const auth = admin.auth();
const { Timestamp, FieldValue } = admin.firestore;

async function clearCollection(colName) {
  const snap = await db.collection(colName).get();
  if (snap.empty) return;
  const chunks = [];
  for (let i = 0; i < snap.docs.length; i += 400) {
    chunks.push(snap.docs.slice(i, i + 400));
  }
  for (const chunk of chunks) {
    const batch = db.batch();
    chunk.forEach(d => batch.delete(d.ref));
    await batch.commit();
  }
}

async function syncAll() {
  const records = JSON.parse(fs.readFileSync('functions/scripts/real_data.json', 'utf8'));
  console.log(`Loaded ${records.length} student records from real_data.json`);

  // 1. Clear Firestore collections (including tasks, assignments, submissions as requested)
  const cols = ['batches', 'users', 'mentors', 'students', 'uniques', 'assignments', 'submissions', 'tasks', 'potd_submissions'];
  for (const c of cols) {
    await clearCollection(c);
    console.log(`Cleared collection: ${c}`);
  }

  // 2. Map existing Auth users by email so we can reuse UIDs or create missing ones quickly
  const existingAuthByEmail = {};
  let pageToken;
  do {
    const res = await auth.listUsers(1000, pageToken);
    for (const u of res.users) {
      if (u.email) existingAuthByEmail[u.email.toLowerCase()] = u;
    }
    pageToken = res.pageToken;
  } while (pageToken);
  console.log(`Found ${Object.keys(existingAuthByEmail).length} existing Auth accounts.`);

  async function ensureAuthUser(email, password, name, role) {
    const lower = email.toLowerCase();
    let u = existingAuthByEmail[lower];
    if (!u) {
      u = await auth.createUser({ email: lower, password, displayName: name });
      await auth.setCustomUserClaims(u.uid, { role });
      existingAuthByEmail[lower] = u;
    } else {
      await auth.updateUser(u.uid, { displayName: name, password });
      await auth.setCustomUserClaims(u.uid, { role });
    }
    return u.uid;
  }

  // 3. Ensure Super Admin account
  const adminUid = await ensureAuthUser('admin@mentorhub.dev', 'Admin@12345', 'Super Admin', 'ADMIN');
  await db.doc(`users/${adminUid}`).set({
    uid: adminUid,
    email: 'admin@mentorhub.dev',
    role: 'ADMIN',
    name: 'Super Admin',
    isActive: true,
    mustChangePassword: false,
    batchId: null,
    createdAt: Timestamp.now(),
  });
  console.log(`Admin ready: admin@mentorhub.dev (${adminUid})`);

  // 4. Create the exact 4 batches: G6-B1, G6-B2, G6-B3, G6-B4
  const batchNames = ['G6-B1', 'G6-B2', 'G6-B3', 'G6-B4'];
  const batchMap = {};
  for (const bName of batchNames) {
    const bId = bName.toLowerCase().replace(/[^a-z0-9]/g, '_'); // deterministic clean id e.g. g6_b1
    await db.doc(`batches/${bId}`).set({
      name: bName,
      academicYear: '2024-25',
      isActive: true,
      startDate: Timestamp.now(),
      endDate: Timestamp.fromDate(new Date(Date.now() + 365 * 86400000)),
      createdAt: Timestamp.now(),
    });
    batchMap[bName] = bId;
    console.log(`Created Batch: ${bName} -> id=${bId}`);
  }

  // 5. Create all 42 Mentors
  const mentorInfoMap = {}; // mentorRollNo -> { code, name, batchName, studentCount }
  for (const r of records) {
    if (!mentorInfoMap[r.mentorRollNo]) {
      mentorInfoMap[r.mentorRollNo] = {
        code: r.mentorRollNo,
        name: r.mentorName,
        batchName: r.batch,
        studentCount: 0,
      };
    }
    mentorInfoMap[r.mentorRollNo].studentCount += 1;
  }

  const mentorUidMap = {}; // mentorRollNo -> uid
  const mentorEntries = Object.values(mentorInfoMap);
  let wBatch = db.batch();
  let ops = 0;

  for (const m of mentorEntries) {
    const email = `${m.code.toLowerCase()}@mentorhub.dev`;
    const uid = await ensureAuthUser(email, 'Mentor@12345', m.name, 'MENTOR');
    mentorUidMap[m.code] = uid;
    const batchId = batchMap[m.batchName];

    wBatch.set(db.doc(`users/${uid}`), {
      uid,
      email,
      role: 'MENTOR',
      name: m.name,
      mentorCode: m.code,
      isActive: true,
      mustChangePassword: false,
      batchId,
      batchName: m.batchName,
      createdAt: Timestamp.now(),
    });
    wBatch.set(db.doc(`mentors/${uid}`), {
      uid,
      mentorCode: m.code,
      name: m.name,
      phone: null,
      email,
      batchId,
      batchName: m.batchName,
      studentCount: m.studentCount,
      isActive: true,
      leetcode: null,
      codeforce: null,
      hackerrank: null,
      linkedin: null,
      github: null,
      resume: null,
      createdAt: Timestamp.now(),
    });
    wBatch.set(db.doc(`uniques/${encodeURIComponent(`mentor|${batchId}|${m.code.toLowerCase()}`)}`), {
      createdAt: Timestamp.now(),
    });
    ops += 3;
    if (ops >= 350) {
      await wBatch.commit();
      wBatch = db.batch();
      ops = 0;
    }
  }
  if (ops > 0) {
    await wBatch.commit();
    wBatch = db.batch();
    ops = 0;
  }
  console.log(`Created ${mentorEntries.length} Mentors.`);

  // 6. Create all 496 Students and link every single one to their exact Mentor and Batch
  const emptyStats = {
    ASSIGNED: 0,
    IN_PROGRESS: 0,
    SUBMITTED: 0,
    APPROVED: 0,
    NEEDS_CHANGES: 0,
    OVERDUE: 0,
  };

  let stuCount = 0;
  for (const r of records) {
    const email = `${r.rollNo.toLowerCase()}@mentorhub.dev`;
    const uid = await ensureAuthUser(email, 'Student@12345', r.studentName, 'STUDENT');
    const batchId = batchMap[r.batch];
    const mentorId = mentorUidMap[r.mentorRollNo];

    wBatch.set(db.doc(`users/${uid}`), {
      uid,
      email,
      role: 'STUDENT',
      name: r.studentName,
      studentCode: r.rollNo,
      branch: r.branch,
      isActive: true,
      mustChangePassword: false,
      batchId,
      batchName: r.batch,
      seniorUid: mentorId,
      createdAt: Timestamp.now(),
    });

    wBatch.set(db.doc(`students/${uid}`), {
      uid,
      studentCode: r.rollNo,
      name: r.studentName,
      branch: r.branch,
      phone: null,
      email,
      batchId,
      batchName: r.batch,
      mentorId,
      mentorCode: r.mentorRollNo,
      mentorName: r.mentorName,
      leetcode: r.leetcode,
      codeforce: r.codeforce,
      hackerrank: r.hackerrank,
      linkedin: r.linkedin,
      github: r.github,
      resume: r.resume,
      stats: emptyStats,
      potdCount: 0,
      potdStreak: 0,
      milestone: 'Starter',
      isActive: true,
      createdAt: Timestamp.now(),
    });

    wBatch.set(db.doc(`uniques/${encodeURIComponent(`student|${batchId}|${r.rollNo.toLowerCase()}`)}`), {
      createdAt: Timestamp.now(),
    });

    ops += 3;
    stuCount++;
    if (ops >= 350) {
      await wBatch.commit();
      wBatch = db.batch();
      ops = 0;
      console.log(`Synced ${stuCount}/496 students...`);
    }
  }
  if (ops > 0) {
    await wBatch.commit();
  }
  console.log(`Successfully synced all ${stuCount} students across 4 batches with 0 unassigned mentees!`);

  // 7. Seed today's Problem of the Day (POTD) so students & mentors can test POTD immediately
  const todayKey = new Date().toISOString().slice(0, 10);
  const sampleMentorUid = mentorUidMap['2303A51408'];
  await db.collection('potd').doc(todayKey).set({
    id: todayKey,
    dateKey: todayKey,
    title: 'Maximum Subarray (Kadane\'s Algorithm)',
    platform: 'LEETCODE',
    problemUrl: 'https://leetcode.com/problems/maximum-subarray/',
    difficulty: 'MEDIUM',
    topic: 'Dynamic Programming / Arrays',
    description: 'Given an integer array nums, find the subarray with the largest sum, and return its sum. Solve in O(n) time complexity.',
    mentorId: sampleMentorUid,
    mentorName: 'DESINI CHARANVITHA',
    mentorCode: '2303A51408',
    solvedCount: 0,
    createdAt: Timestamp.now(),
  });
  console.log(`Seeded today's Problem of the Day (${todayKey})!`);
}

syncAll().then(() => process.exit(0)).catch(e => {
  console.error(e);
  process.exit(1);
});
