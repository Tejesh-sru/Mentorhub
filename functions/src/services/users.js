const { db, auth, FieldValue } = require('../init');
const { AppError } = require('../errors');
const { emptyStats, statsMove } = require('../stats');
const { defaultPassword } = require('../util');
const { runBulk } = require('../bulk');

async function getBatch(batchId) {
  const snap = await db.doc(`batches/${batchId}`).get();
  if (!snap.exists) throw new AppError('not-found', 'Batch not found');
  return { id: snap.id, ...snap.data() };
}

// Mentor / student codes must be unique per batch. We reserve them with a create-only lock document.
async function reserveUnique(key, label) {
  const ref = db.collection('uniques').doc(encodeURIComponent(key));
  try {
    await ref.create({ createdAt: FieldValue.serverTimestamp() });
  } catch (e) {
    if (e.code === 6) throw new AppError('already-exists', `${label} already exists in this batch`);
    throw e;
  }
  return ref;
}

async function createAuthUser({ email, password, role, name }) {
  try {
    const user = await auth.createUser({ email, password, displayName: name });
    await auth.setCustomUserClaims(user.uid, { role });
    return user;
  } catch (e) {
    if (e.code === 'auth/email-already-exists') throw new AppError('already-exists', 'A user with this email already exists');
    if (e.code === 'auth/invalid-password') throw new AppError('invalid-argument', 'Password is too weak');
    throw e;
  }
}

async function createAdmin({ email, password, name = 'Administrator' }) {
  const user = await createAuthUser({ email, password, role: 'ADMIN', name });
  await db.doc(`users/${user.uid}`).set({
    email, role: 'ADMIN', name, isActive: true, mustChangePassword: false, batchId: null, createdAt: FieldValue.serverTimestamp(),
  });
  return { uid: user.uid };
}

async function createMentor(input, { password } = {}) {
  await getBatch(input.batchId);
  const lock = await reserveUnique(`mentor|${input.batchId}|${input.mentorCode.toLowerCase()}`, 'This mentor ID');
  let user;
  try {
    const pw = password || input.password || defaultPassword();
    user = await createAuthUser({ email: input.email, password: pw, role: 'MENTOR', name: input.name });
    const w = db.batch();
    w.set(db.doc(`users/${user.uid}`), {
      email: input.email, role: 'MENTOR', name: input.name, isActive: true,
      mustChangePassword: !(password || input.password), batchId: input.batchId, createdAt: FieldValue.serverTimestamp(),
    });
    w.set(db.doc(`mentors/${user.uid}`), {
      mentorCode: input.mentorCode, name: input.name, phone: input.phone || null, email: input.email,
      batchId: input.batchId, createdAt: FieldValue.serverTimestamp(),
      leetcode: input.leetcode || null,
      codeforce: input.codeforce || null,
      hackerrank: input.hackerrank || null,
      linkedin: input.linkedin || null,
      github: input.github || null,
      resume: input.resume || null,
    });
    await w.commit();
    return { uid: user.uid };
  } catch (e) {
    await lock.delete().catch(() => {});
    if (user) await auth.deleteUser(user.uid).catch(() => {});
    throw e;
  }
}

async function createStudent(input, { password } = {}) {
  await getBatch(input.batchId);
  if (input.mentorId) await assertMentorInBatch(input.mentorId, input.batchId);
  const lock = await reserveUnique(`student|${input.batchId}|${input.studentCode.toLowerCase()}`, 'This student ID');
  let user;
  try {
    const pw = password || input.password || defaultPassword();
    user = await createAuthUser({ email: input.email, password: pw, role: 'STUDENT', name: input.name });
    const w = db.batch();
    w.set(db.doc(`users/${user.uid}`), {
      email: input.email, role: 'STUDENT', name: input.name, isActive: true,
      mustChangePassword: !(password || input.password), batchId: input.batchId, createdAt: FieldValue.serverTimestamp(),
    });
    w.set(db.doc(`students/${user.uid}`), {
      studentCode: input.studentCode, name: input.name, phone: input.phone || null, email: input.email,
      batchId: input.batchId, mentorId: input.mentorId || null, stats: emptyStats(), createdAt: FieldValue.serverTimestamp(),
      leetcode: input.leetcode || null,
      codeforce: input.codeforce || null,
      hackerrank: input.hackerrank || null,
      linkedin: input.linkedin || null,
      github: input.github || null,
      resume: input.resume || null,
    });
    await w.commit();
    return { uid: user.uid };
  } catch (e) {
    await lock.delete().catch(() => {});
    if (user) await auth.deleteUser(user.uid).catch(() => {});
    throw e;
  }
}

async function assertMentorInBatch(mentorId, batchId) {
  const snap = await db.doc(`mentors/${mentorId}`).get();
  if (!snap.exists || snap.data().batchId !== batchId) throw new AppError('not-found', 'Mentor not found in this batch');
  return snap.data();
}

async function setActive(actorUid, uid, isActive) {
  if (actorUid === uid && !isActive) throw new AppError('failed-precondition', 'You cannot deactivate your own account');
  const ref = db.doc(`users/${uid}`);
  if (!(await ref.get()).exists) throw new AppError('not-found', 'User not found');
  await auth.updateUser(uid, { disabled: !isActive });
  if (!isActive) await auth.revokeRefreshTokens(uid);
  await ref.update({ isActive });
}

async function resetPassword(uid) {
  const ref = db.doc(`users/${uid}`);
  if (!(await ref.get()).exists) throw new AppError('not-found', 'User not found');
  await auth.updateUser(uid, { password: defaultPassword() });
  await auth.revokeRefreshTokens(uid);
  await ref.update({ mustChangePassword: true });
}

async function markPasswordChanged(uid) {
  await db.doc(`users/${uid}`).update({ mustChangePassword: false });
}

// Reassigning a student must also move their denormalised assignment / submission rows to the new mentor.
async function updateStudentMentor(studentId, mentorId) {
  const ref = db.doc(`students/${studentId}`);
  const snap = await ref.get();
  if (!snap.exists) throw new AppError('not-found', 'Student not found');
  const studentData = snap.data();
  if (mentorId) await assertMentorInBatch(mentorId, studentData.batchId);
  const [assignments, submissions] = await Promise.all([
    db.collection('assignments').where('studentId', '==', studentId).get(),
    db.collection('submissions').where('studentId', '==', studentId).get(),
  ]);
  await runBulk((w) => {
    w.update(ref, { mentorId: mentorId || null, seniorUid: mentorId || null });
    w.set(db.doc(`users/${studentId}`), { seniorUid: mentorId || null }, { merge: true });
    assignments.docs.forEach((d) => w.update(d.ref, { mentorId: mentorId || null, seniorUid: mentorId || null }));
    submissions.docs.forEach((d) => w.update(d.ref, { mentorId: mentorId || null, seniorUid: mentorId || null }));

    // Create / update CSSP pairing document in assignments/{batchId}_{studentId}
    if (studentData.batchId) {
      const pairRef = db.doc(`assignments/${studentData.batchId}_${studentId}`);
      w.set(pairRef, {
        batchId: studentData.batchId,
        seniorUid: mentorId || null,
        mentorId: mentorId || null,
        juniorUid: studentId,
        studentId: studentId,
        effectiveFrom: FieldValue.serverTimestamp(),
        active: Boolean(mentorId),
      }, { merge: true });
    }
  });

  // Log immutable audit entry for assignment transfer (Blueprint Section 7)
  try {
    await db.collection('auditLogs').add({
      actorUid: 'admin',
      actorRole: 'ADMIN',
      action: 'TRANSFER_ASSIGNMENT',
      targetPath: `students/${studentId}`,
      timestamp: FieldValue.serverTimestamp(),
      changedFields: {
        previousMentorId: studentData.mentorId || null,
        newMentorId: mentorId || null,
      },
    });
  } catch (err) {
    console.warn('Failed to log audit for assignment transfer:', err.message);
  }
}

// Repair tool: rebuilds every student's stats counters from the assignments collection.
async function recomputeStats() {
  const [students, assignments] = await Promise.all([
    db.collection('students').select().get(),
    db.collection('assignments').select('studentId', 'status').get(),
  ]);
  const map = new Map(students.docs.map((d) => [d.id, emptyStats()]));
  assignments.docs.forEach((d) => {
    const { studentId, status } = d.data();
    if (map.has(studentId)) map.get(studentId)[status] += 1;
  });
  await runBulk((w) => { map.forEach((stats, id) => w.update(db.doc(`students/${id}`), { stats })); });
  return { students: map.size, assignments: assignments.size };
}

module.exports = {
  getBatch, createAdmin, createMentor, createStudent, setActive, resetPassword, markPasswordChanged,
  updateStudentMentor, recomputeStats, assertMentorInBatch,
};
