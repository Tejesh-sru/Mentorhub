const { db, FieldValue, Timestamp } = require('../init');
const { AppError } = require('../errors');
const { statsMove } = require('../stats');
const { notificationData } = require('../notify');
const { runBulk } = require('../bulk');
const { chunk, formatDate } = require('../util');
const { getBatch, assertMentorInBatch } = require('./users');

// Resolves { type: BATCH | MENTOR | STUDENTS } into student rows ({ id, ...data }) inside the task's batch.
async function resolveStudents(batchId, target) {
  if (!target) return [];
  if (target.type === 'BATCH') {
    const snap = await db.collection('students').where('batchId', '==', batchId).get();
    return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  }
  if (target.type === 'MENTOR') {
    await assertMentorInBatch(target.mentorId, batchId);
    const snap = await db.collection('students').where('mentorId', '==', target.mentorId).get();
    return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  }
  const ids = [...new Set(target.studentIds)];
  const rows = [];
  for (const part of chunk(ids, 300)) {
    const snaps = await db.getAll(...part.map((id) => db.doc(`students/${id}`)));
    snaps.forEach((s) => { if (s.exists && s.data().batchId === batchId) rows.push({ id: s.id, ...s.data() }); });
  }
  if (rows.length !== ids.length) throw new AppError('invalid-argument', 'Some selected students were not found in this batch');
  return rows;
}

const assignmentData = (taskId, task, student) => ({
  taskId,
  studentId: student.id,
  mentorId: student.mentorId || null,
  batchId: task.batchId,
  status: 'ASSIGNED',
  assignedAt: FieldValue.serverTimestamp(),
  startedAt: null, submittedAt: null, reviewedAt: null,
  reminded: false,
  deadline: task.deadline,
  // denormalised so lists never need joins
  taskTitle: task.title, taskDescription: task.description || null, platform: task.platform,
  problemUrl: task.problemUrl, difficulty: task.difficulty, topic: task.topic,
  studentName: student.name, studentCode: student.studentCode,
});

// Creates the missing assignments, bumps counters, notifies. Existing (task, student) pairs are skipped.
async function assignMany(taskId, task, students) {
  const existing = new Set();
  for (const part of chunk(students, 300)) {
    const snaps = await db.getAll(...part.map((s) => db.doc(`assignments/${taskId}_${s.id}`)));
    snaps.forEach((s) => { if (s.exists) existing.add(s.id); });
  }
  const fresh = students.filter((s) => !existing.has(`${taskId}_${s.id}`));
  if (!fresh.length) return 0;

  const msg = {
    title: 'New task assigned',
    message: `"${task.title}" (${task.difficulty.toLowerCase()}, ${task.topic}) is due ${formatDate(task.deadline.toDate())}.`,
    type: 'TASK_ASSIGNED',
  };
  await runBulk((w) => {
    fresh.forEach((s) => {
      w.create(db.doc(`assignments/${taskId}_${s.id}`), assignmentData(taskId, task, s));
      w.update(db.doc(`students/${s.id}`), statsMove(null, 'ASSIGNED'));
      w.create(db.collection('notifications').doc(), notificationData(s.id, msg));
    });
  });
  return fresh.length;
}

async function createTask(adminUid, input) {
  const { assignTo, ...data } = input;
  await getBatch(data.batchId);
  const students = await resolveStudents(data.batchId, assignTo); // validate before writing anything
  const ref = db.collection('tasks').doc();
  const task = { ...data, deadline: Timestamp.fromDate(new Date(data.deadline)), createdBy: adminUid, createdAt: FieldValue.serverTimestamp() };
  await ref.set(task);
  const assignedCount = await assignMany(ref.id, task, students);
  return { taskId: ref.id, assignedCount };
}

async function assignTask(taskId, assignTo) {
  const snap = await db.doc(`tasks/${taskId}`).get();
  if (!snap.exists) throw new AppError('not-found', 'Task not found');
  const task = snap.data();
  const students = await resolveStudents(task.batchId, assignTo);
  const assignedCount = await assignMany(taskId, task, students);
  return { assignedCount, skipped: students.length - assignedCount };
}

async function deleteTask(taskId) {
  const taskRef = db.doc(`tasks/${taskId}`);
  if (!(await taskRef.get()).exists) throw new AppError('not-found', 'Task not found');
  const assignments = await db.collection('assignments').where('taskId', '==', taskId).get();
  await runBulk((w) => {
    assignments.docs.forEach((d) => {
      const a = d.data();
      w.update(db.doc(`students/${a.studentId}`), statsMove(a.status, null));
      w.delete(db.doc(`submissions/${d.id}`));
      w.delete(d.ref);
    });
    w.delete(taskRef);
  });
  return { removedAssignments: assignments.size };
}

module.exports = { createTask, assignTask, deleteTask, resolveStudents };
