const { db, FieldValue } = require('../init');
const { AppError } = require('../errors');
const { EDITABLE_STATUSES } = require('../constants');
const { statsMove } = require('../stats');
const { notificationData } = require('../notify');

async function startAssignment(studentUid, assignmentId) {
  const ref = db.doc(`assignments/${assignmentId}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists || snap.data().studentId !== studentUid) throw new AppError('not-found', 'Task not found');
    const a = snap.data();
    if (a.status === 'ASSIGNED') {
      tx.update(ref, { status: 'IN_PROGRESS', startedAt: FieldValue.serverTimestamp() });
      tx.update(db.doc(`students/${studentUid}`), statsMove('ASSIGNED', 'IN_PROGRESS'));
    } else if (a.status === 'OVERDUE' && !a.startedAt) {
      tx.update(ref, { startedAt: FieldValue.serverTimestamp() });
    } else if (a.status !== 'IN_PROGRESS' && a.status !== 'OVERDUE') {
      throw new AppError('failed-precondition', 'This task cannot be started in its current state');
    }
  });
}

// Creates (or revises) the submission. A task can never be completed without this payload, and only
// reviewSubmission() can set APPROVED.
async function submitAssignment(studentUid, input) {
  const aRef = db.doc(`assignments/${input.assignmentId}`);
  const sRef = db.doc(`submissions/${input.assignmentId}`);
  return db.runTransaction(async (tx) => {
    const [aSnap, sSnap] = await Promise.all([tx.get(aRef), tx.get(sRef)]);
    if (!aSnap.exists || aSnap.data().studentId !== studentUid) throw new AppError('not-found', 'Task not found');
    const a = aSnap.data();
    if (!EDITABLE_STATUSES.includes(a.status)) {
      throw new AppError('failed-precondition', a.status === 'APPROVED' ? 'This task is already approved' : 'This submission is awaiting mentor review');
    }
    if (a.platform !== 'OTHER' && !input.solutionUrl) {
      throw new AppError('invalid-argument', `A solution URL is required for ${a.platform} tasks`);
    }

    const prev = sSnap.exists ? sSnap.data() : null;
    const now = FieldValue.serverTimestamp();
    tx.set(sRef, {
      assignmentId: input.assignmentId, taskId: a.taskId, studentId: a.studentId, mentorId: a.mentorId,
      batchId: a.batchId, studentName: a.studentName, studentCode: a.studentCode,
      taskTitle: a.taskTitle, topic: a.topic, difficulty: a.difficulty, platform: a.platform,
      problemUrl: a.problemUrl, deadline: a.deadline,
      understanding: input.understanding, approach: input.approach,
      timeComplexity: input.timeComplexity, spaceComplexity: input.spaceComplexity,
      solutionUrl: input.solutionUrl || null, code: input.code || null,
      mentorFeedback: prev ? prev.mentorFeedback || null : null,
      reviewStatus: 'PENDING', revision: prev ? prev.revision + 1 : 1,
      submittedAt: now, reviewedAt: null,
    });
    tx.update(aRef, { status: 'SUBMITTED', submittedAt: now, reviewedAt: null, startedAt: a.startedAt || now });
    tx.update(db.doc(`students/${studentUid}`), statsMove(a.status, 'SUBMITTED'));
    if (a.mentorId) {
      tx.set(db.collection('notifications').doc(), notificationData(a.mentorId, {
        title: 'New submission to review',
        message: `${a.studentName} submitted "${a.taskTitle}"${prev ? ' (revised)' : ''}.`,
        type: 'SUBMISSION_RECEIVED',
      }));
    }
    return { submissionId: input.assignmentId, revision: prev ? prev.revision + 1 : 1 };
  });
}

// Mentor only (enforced by the caller wrapper + the mentorId check below).
async function reviewSubmission(mentorUid, { submissionId, decision, feedback }) {
  const sRef = db.doc(`submissions/${submissionId}`);
  const aRef = db.doc(`assignments/${submissionId}`);
  await db.runTransaction(async (tx) => {
    const [sSnap, aSnap] = await Promise.all([tx.get(sRef), tx.get(aRef)]);
    if (!sSnap.exists || sSnap.data().mentorId !== mentorUid) throw new AppError('not-found', 'Submission not found');
    const s = sSnap.data();
    if (s.reviewStatus !== 'PENDING' || aSnap.data().status !== 'SUBMITTED') {
      throw new AppError('failed-precondition', 'This submission has already been reviewed');
    }
    const approved = decision === 'APPROVED';
    const now = FieldValue.serverTimestamp();
    tx.update(sRef, { reviewStatus: decision, mentorFeedback: feedback || null, reviewedAt: now });
    tx.update(aRef, { status: decision, reviewedAt: now });
    tx.update(db.doc(`students/${s.studentId}`), statsMove('SUBMITTED', decision));
    tx.set(db.collection('notifications').doc(), notificationData(s.studentId, {
      title: approved ? 'Task approved' : 'Changes requested',
      message: approved
        ? `Your submission for "${s.taskTitle}" was approved.`
        : `Your mentor requested changes on "${s.taskTitle}". Check the feedback and resubmit.`,
      type: approved ? 'TASK_APPROVED' : 'CHANGES_REQUESTED',
    }));
  });
}

module.exports = { startAssignment, submitAssignment, reviewSubmission };
