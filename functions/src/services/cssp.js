const { db, auth, FieldValue, Timestamp } = require('../init');
const { AppError } = require('../errors');
const { notifyUsers } = require('../notify');
const users = require('./users');

async function isCallerPrivileged(uid) {
  const userSnap = await db.doc(`users/${uid}`).get();
  if (!userSnap.exists) return false;
  const role = userSnap.data().role;
  return role === 'ADMIN' || role === 'SUPER_ADMIN';
}

async function assertSeniorCanManageJunior(seniorUid, juniorUid) {
  if (await isCallerPrivileged(seniorUid)) return;
  const studentSnap = await db.doc(`students/${juniorUid}`).get();
  if (!studentSnap.exists) throw new AppError('not-found', 'Junior student not found');
  const studentData = studentSnap.data();
  if (studentData.mentorId !== seniorUid && studentData.seniorUid !== seniorUid) {
    throw new AppError('permission-denied', 'Permission denied: A senior can review only assigned juniors.');
  }
}

async function logAudit({ actorUid, actorRole, action, targetPath, changedFields }) {
  try {
    const ref = db.collection('auditLogs').doc();
    await ref.set({
      actorUid: actorUid || 'system',
      actorRole: actorRole || null,
      action,
      targetPath,
      timestamp: FieldValue.serverTimestamp(),
      changedFields: changedFields || {},
    });
    return ref.id;
  } catch (err) {
    console.warn('Failed to write audit log:', err.message);
  }
}

async function submitWeeklyProgress(juniorUid, input) {
  const { batchId, weekId, claimedCount, problemName, problemUrl, approach } = input;
  if (!batchId || !weekId) throw new AppError('invalid-argument', 'batchId and weekId are required');
  if (typeof claimedCount !== 'number' || claimedCount < 0) {
    throw new AppError('invalid-argument', 'Claimed LeetCode count must be a non-negative number');
  }

  // Look up student profile to associate mentor
  let seniorUid = null;
  const studentSnap = await db.doc(`students/${juniorUid}`).get();
  if (studentSnap.exists) {
    seniorUid = studentSnap.data().mentorId || studentSnap.data().seniorUid || null;
  }

  const docId = `${batchId}_${weekId}_${juniorUid}`;
  const ref = db.doc(`submissions/${docId}`);
  const existing = await ref.get();

  const data = {
    juniorUid,
    studentId: juniorUid,
    seniorUid,
    mentorId: seniorUid,
    batchId,
    weekId,
    claimedCount: Math.floor(claimedCount),
    problemName: problemName ? String(problemName).trim() : null,
    problemUrl: problemUrl ? String(problemUrl).trim() : null,
    approach: approach ? String(approach).trim() : null,
    status: 'AWAITING_REVIEW',
    submittedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };

  // Preserve any existing verified fields if updating claimed count before review
  if (existing.exists) {
    const prev = existing.data();
    if (prev.verifiedCount !== undefined) data.verifiedCount = prev.verifiedCount;
    if (prev.verificationStatus !== undefined) data.verificationStatus = prev.verificationStatus;
    if (prev.seriousness !== undefined) data.seriousness = prev.seriousness;
    if (prev.remarks !== undefined) data.remarks = prev.remarks;
    if (prev.checkedAt !== undefined) data.checkedAt = prev.checkedAt;
    if (prev.checkedByUid !== undefined) data.checkedByUid = prev.checkedByUid;
  }

  await ref.set(data, { merge: true });

  await logAudit({
    actorUid: juniorUid,
    actorRole: 'STUDENT',
    action: 'SUBMIT_WEEKLY_PROGRESS',
    targetPath: `submissions/${docId}`,
    changedFields: { claimedCount, problemName, weekId },
  });

  // Notify senior mentor if assigned
  if (seniorUid) {
    await notifyUsers([seniorUid], {
      title: 'New Weekly Submission',
      message: `Junior mentee submitted ${Math.floor(claimedCount)} problems for ${weekId}.`,
      type: 'SUBMISSION',
    }).catch(() => {});
  }

  return { ok: true, id: docId };
}

async function verifyWeeklyProgress(seniorUid, input) {
  const { submissionId, batchId, weekId, juniorUid, verifiedCount, verificationStatus, seriousness, remarks } = input;
  const docId = submissionId || `${batchId}_${weekId}_${juniorUid}`;
  if (!docId) throw new AppError('invalid-argument', 'Submission identifier is required');

  if (typeof verifiedCount !== 'number' || verifiedCount < 0) {
    throw new AppError('invalid-argument', 'Verified count must be a non-negative number');
  }

  const validStatuses = ['VERIFIED', 'DOUBTFUL', 'NOT_CHECKED'];
  if (!validStatuses.includes(verificationStatus)) {
    throw new AppError('invalid-argument', `Invalid verificationStatus. Must be one of: ${validStatuses.join(', ')}`);
  }

  const validSeriousness = ['HIGH', 'MEDIUM', 'LOW'];
  if (!validSeriousness.includes(seriousness)) {
    throw new AppError('invalid-argument', `Invalid seriousness. Must be one of: ${validSeriousness.join(', ')}`);
  }

  // Acceptance Criterion: A senior can review only assigned juniors
  if (juniorUid) {
    await assertSeniorCanManageJunior(seniorUid, juniorUid);
  }

  const subRef = db.doc(`submissions/${docId}`);
  const verRef = db.doc(`verifications/${docId}`);

  const updateData = {
    verifiedCount: Math.floor(verifiedCount),
    verificationStatus,
    seriousness,
    remarks: remarks ? String(remarks).trim() : '',
    checkedAt: FieldValue.serverTimestamp(),
    checkedByUid: seniorUid,
    reviewedBy: seniorUid,
    reviewedAt: FieldValue.serverTimestamp(),
    status: verificationStatus === 'VERIFIED' ? 'VERIFIED' : (verificationStatus === 'DOUBTFUL' ? 'DOUBTFUL' : 'AWAITING_REVIEW'),
    updatedAt: FieldValue.serverTimestamp(),
  };

  const verData = {
    submissionId: docId,
    batchId: batchId || null,
    weekId: weekId || null,
    juniorUid: juniorUid || null,
    verifiedCount: Math.floor(verifiedCount),
    verificationStatus,
    seriousness,
    remarks: remarks ? String(remarks).trim() : '',
    checkedAt: FieldValue.serverTimestamp(),
    checkedByUid: seniorUid,
  };

  const b = db.batch();
  b.set(subRef, updateData, { merge: true });
  b.set(verRef, verData, { merge: true });
  await b.commit();

  await logAudit({
    actorUid: seniorUid,
    actorRole: 'MENTOR',
    action: 'VERIFY_WEEKLY_PROGRESS',
    targetPath: `submissions/${docId}`,
    changedFields: { verifiedCount, verificationStatus, seriousness, remarks },
  });

  // Notify junior mentee of verification result
  if (juniorUid) {
    await notifyUsers([juniorUid], {
      title: 'Weekly Progress Verified',
      message: `Your ${weekId || 'weekly'} progress was verified: ${Math.floor(verifiedCount)} problems (${verificationStatus}).`,
      type: 'VERIFICATION',
    }).catch(() => {});
  }

  return { ok: true, id: docId };
}

async function scheduleMock(callerUid, input) {
  const { batchId, weekId, juniorUid, scheduledAt, topic, meetingLink, durationMinutes, notes, status } = input;
  if (!batchId || !weekId || !juniorUid) {
    throw new AppError('invalid-argument', 'batchId, weekId, and juniorUid are required');
  }

  // Acceptance Criterion: A senior can manage only assigned juniors; Admins can manage any
  await assertSeniorCanManageJunior(callerUid, juniorUid);

  let targetSeniorUid = input.seniorUid;
  if (!targetSeniorUid) {
    const studentSnap = await db.doc(`students/${juniorUid}`).get();
    if (studentSnap.exists) {
      targetSeniorUid = studentSnap.data().mentorId || studentSnap.data().seniorUid || callerUid;
    } else {
      targetSeniorUid = callerUid;
    }
  }

  const docId = `${batchId}_${weekId}_${juniorUid}`;
  const ref = db.doc(`mocks/${docId}`);

  const mockStatus = status || 'SCHEDULED';
  const data = {
    batchId,
    weekId,
    juniorUid,
    seniorUid: targetSeniorUid,
    evaluatorUid: callerUid,
    status: mockStatus,
    scheduledAt: scheduledAt ? Timestamp.fromDate(new Date(scheduledAt)) : FieldValue.serverTimestamp(),
    topic: topic ? String(topic).trim() : null,
    meetingLink: meetingLink ? String(meetingLink).trim() : null,
    durationMinutes: durationMinutes ? Number(durationMinutes) : 30,
    notes: notes ? String(notes).trim() : null,
    updatedAt: FieldValue.serverTimestamp(),
  };

  await ref.set(data, { merge: true });

  const isCallerAdmin = await isCallerPrivileged(callerUid);
  await logAudit({
    actorUid: callerUid,
    actorRole: isCallerAdmin ? 'ADMIN' : 'MENTOR',
    action: 'SCHEDULE_MOCK',
    targetPath: `mocks/${docId}`,
    changedFields: { scheduledAt, status: mockStatus, topic, meetingLink, durationMinutes },
  });

  await notifyUsers([juniorUid], {
    title: 'Mock Interview Scheduled',
    message: topic
      ? `A mock interview on "${topic}" has been scheduled for ${weekId}.`
      : `A mock interview has been scheduled for ${weekId}.`,
    type: 'MOCK',
  }).catch(() => {});

  return { ok: true, id: docId };
}

async function evaluateMock(seniorUid, input) {
  const { batchId, weekId, juniorUid, score10, technical5, communication5, problemSolving5, recommendation, notes, status } = input;
  if (!batchId || !weekId || !juniorUid) {
    throw new AppError('invalid-argument', 'batchId, weekId, and juniorUid are required');
  }

  // Acceptance Criterion: A senior can manage only assigned juniors
  await assertSeniorCanManageJunior(seniorUid, juniorUid);

  // Validate score ranges according to specification
  if (typeof score10 !== 'number' || score10 < 0 || score10 > 10) {
    throw new AppError('invalid-argument', 'Overall score must be between 0 and 10');
  }
  if (typeof technical5 !== 'number' || technical5 < 0 || technical5 > 5) {
    throw new AppError('invalid-argument', 'Technical score must be between 0 and 5');
  }
  if (typeof communication5 !== 'number' || communication5 < 0 || communication5 > 5) {
    throw new AppError('invalid-argument', 'Communication score must be between 0 and 5');
  }
  if (typeof problemSolving5 !== 'number' || problemSolving5 < 0 || problemSolving5 > 5) {
    throw new AppError('invalid-argument', 'Problem solving score must be between 0 and 5');
  }

  const validStatuses = ['NOT_PLANNED', 'SCHEDULED', 'COMPLETED', 'MISSED'];
  const mockStatus = status && validStatuses.includes(status) ? status : 'COMPLETED';

  const docId = `${batchId}_${weekId}_${juniorUid}`;
  const ref = db.doc(`mocks/${docId}`);

  // Specification rule: Treat overall /10 and independent /5 criteria as separate assessments. Do not sum automatically into /10.
  const data = {
    batchId,
    weekId,
    juniorUid,
    seniorUid,
    evaluatorUid: seniorUid,
    status: mockStatus,
    score10: Number(score10),
    technical5: Number(technical5),
    communication5: Number(communication5),
    problemSolving5: Number(problemSolving5),
    recommendation: recommendation ? String(recommendation).trim() : '',
    notes: notes ? String(notes).trim() : '',
    updatedAt: FieldValue.serverTimestamp(),
  };

  await ref.set(data, { merge: true });

  await logAudit({
    actorUid: seniorUid,
    actorRole: 'MENTOR',
    action: 'EVALUATE_MOCK',
    targetPath: `mocks/${docId}`,
    changedFields: { score10, technical5, communication5, problemSolving5, recommendation, status: mockStatus },
  });

  await notifyUsers([juniorUid], {
    title: mockStatus === 'MISSED' ? 'Mock Interview Missed' : 'Mock Interview Evaluated',
    message: mockStatus === 'MISSED'
      ? `Your ${weekId} mock interview was marked missed. Please reschedule with your senior mentor.`
      : `Your ${weekId} mock score: ${score10}/10. Technical: ${technical5}/5.`,
    type: 'MOCK',
  }).catch(() => {});

  return { ok: true, id: docId };
}

async function updateWeeklyConfig(adminUid, input) {
  const { batchId, weeks } = input;
  if (!batchId || !Array.isArray(weeks)) {
    throw new AppError('invalid-argument', 'batchId and weeks array are required');
  }

  const batch = db.batch();
  for (const w of weeks) {
    const weekId = w.weekId || w.label || `W${w.order}`;
    const ref = db.doc(`weeks/${batchId}_${weekId}`);
    batch.set(ref, {
      batchId,
      weekId,
      label: w.label || weekId,
      order: typeof w.order === 'number' ? w.order : 1,
      targetCumulative: typeof w.targetCumulative === 'number' ? w.targetCumulative : 98,
      startsAt: w.startsAt ? Timestamp.fromDate(new Date(w.startsAt)) : FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  await batch.commit();

  await logAudit({
    actorUid: adminUid,
    actorRole: 'ADMIN',
    action: 'UPDATE_WEEKLY_CONFIG',
    targetPath: `batches/${batchId}/weeks`,
    changedFields: { weekCount: weeks.length },
  });

  return { ok: true };
}

async function updateProfileLinks(userUid, input) {
  const { leetcodeUrl, codeforcesUrl, hackerRankUrl, linkedInUrl, gitHubUrl, resumeUrl, phone } = input;

  const urlRegex = /^https?:\/\/.+/i;
  const validateUrl = (url, name) => {
    if (url && url.trim().length > 0 && !urlRegex.test(url.trim())) {
      throw new AppError('invalid-argument', `${name} must start with http:// or https://`);
    }
  };

  validateUrl(leetcodeUrl, 'LeetCode URL');
  validateUrl(codeforcesUrl, 'Codeforces URL');
  validateUrl(hackerRankUrl, 'HackerRank URL');
  validateUrl(linkedInUrl, 'LinkedIn URL');
  validateUrl(gitHubUrl, 'GitHub URL');
  validateUrl(resumeUrl, 'Resume URL');

  const linksData = {
    leetcode: leetcodeUrl ? leetcodeUrl.trim() : null,
    codeforce: codeforcesUrl ? codeforcesUrl.trim() : null,
    hackerrank: hackerRankUrl ? hackerRankUrl.trim() : null,
    linkedin: linkedInUrl ? linkedInUrl.trim() : null,
    github: gitHubUrl ? gitHubUrl.trim() : null,
    resume: resumeUrl ? resumeUrl.trim() : null,
    leetcodeUrl: leetcodeUrl ? leetcodeUrl.trim() : null,
    codeforcesUrl: codeforcesUrl ? codeforcesUrl.trim() : null,
    hackerRankUrl: hackerRankUrl ? hackerRankUrl.trim() : null,
    linkedInUrl: linkedInUrl ? linkedInUrl.trim() : null,
    gitHubUrl: gitHubUrl ? gitHubUrl.trim() : null,
    resumeUrl: resumeUrl ? resumeUrl.trim() : null,
    phone: phone ? phone.trim() : null,
    updatedAt: FieldValue.serverTimestamp(),
  };

  const b = db.batch();
  b.set(db.doc(`students/${userUid}`), linksData, { merge: true });
  b.set(db.doc(`profiles/${userUid}`), linksData, { merge: true });
  await b.commit();

  await logAudit({
    actorUid: userUid,
    actorRole: 'STUDENT',
    action: 'UPDATE_PROFILE_LINKS',
    targetPath: `students/${userUid}`,
    changedFields: { updatedLinks: true },
  });

  return { ok: true };
}

async function bulkImportStudentsCssp(adminUid, input) {
  const { batchId, records, fileName = 'import.csv' } = input;
  if (!batchId || !Array.isArray(records)) {
    throw new AppError('invalid-argument', 'batchId and records array are required');
  }

  let imported = 0;
  let updated = 0;
  const errors = [];

  const importRef = db.collection('imports').doc();
  await importRef.set({
    uploadedBy: adminUid,
    batchId,
    fileName,
    status: 'IN_PROGRESS',
    totals: records.length,
    errors: [],
    startedAt: FieldValue.serverTimestamp(),
  });

  for (let i = 0; i < records.length; i++) {
    const row = records[i];
    const rollNo = (row.rollNo || row.studentCode || '').trim();
    const name = (row.studentName || row.name || '').trim();
    if (!rollNo || !name) {
      errors.push({ row: i + 1, message: 'Missing Roll No or Name' });
      continue;
    }

    try {
      // Find existing student by studentCode in batch
      const existingSnap = await db.collection('students')
        .where('batchId', '==', batchId)
        .where('studentCode', '==', rollNo)
        .limit(1)
        .get();

      if (!existingSnap.empty) {
        // Non-destructive upsert: Preserve past verifications, mocks, or remarks
        const doc = existingSnap.docs[0];
        await doc.ref.set({
          name,
          phone: row.phone || null,
          leetcode: row.leetcode || null,
          codeforce: row.codeforce || null,
          hackerrank: row.hackerrank || null,
          linkedin: row.linkedin || null,
          github: row.github || null,
          resume: row.resume || null,
          branch: row.branch || null,
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
        updated++;
      } else {
        // Create new student
        const email = `${rollNo.toLowerCase()}@mentorhub.dev`;
        await users.createStudent({
          studentCode: rollNo,
          name,
          email,
          batchId,
          mentorId: row.mentorId || null,
          phone: row.phone || null,
          leetcode: row.leetcode || null,
          codeforce: row.codeforce || null,
          hackerrank: row.hackerrank || null,
          linkedin: row.linkedin || null,
          github: row.github || null,
          resume: row.resume || null,
        });
        imported++;
      }
    } catch (e) {
      errors.push({ row: i + 1, rollNo, message: e.message });
    }
  }

  await importRef.set({
    status: errors.length > 0 && (imported + updated === 0) ? 'FAILED' : 'COMPLETED',
    imported,
    updated,
    errors,
    completedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await logAudit({
    actorUid: adminUid,
    actorRole: 'ADMIN',
    action: 'BULK_IMPORT_STUDENTS',
    targetPath: `imports/${importRef.id}`,
    changedFields: { imported, updated, errorCount: errors.length },
  });

  return { ok: true, importId: importRef.id, imported, updated, errors };
}

async function createAdminAccount(superAdminUid, input) {
  const { email, password, name = 'Administrator', batchIds = [] } = input;
  if (!email || !password) throw new AppError('invalid-argument', 'Email and password are required');

  const { uid } = await users.createAdmin({ email, password, name });
  if (batchIds && batchIds.length > 0) {
    await db.doc(`users/${uid}`).update({ batchIds });
  }

  await logAudit({
    actorUid: superAdminUid,
    actorRole: 'SUPER_ADMIN',
    action: 'CREATE_ADMIN_ACCOUNT',
    targetPath: `users/${uid}`,
    changedFields: { email, name, batchIds },
  });

  return { ok: true, uid };
}

module.exports = {
  logAudit,
  submitWeeklyProgress,
  verifyWeeklyProgress,
  scheduleMock,
  evaluateMock,
  updateWeeklyConfig,
  updateProfileLinks,
  bulkImportStudentsCssp,
  createAdminAccount,
};
