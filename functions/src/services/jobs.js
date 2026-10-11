const { db, Timestamp } = require('../init');
const { OVERDUE_FROM } = require('../constants');
const { statsMove } = require('../stats');
const { runBulk } = require('../bulk');
const { notifyEach, notifyAdmins } = require('../notify');

const DAY = 24 * 60 * 60 * 1000;
const preview = (arr, n = 3) => arr.slice(0, n).join(', ') + (arr.length > n ? ` +${arr.length - n} more` : '');

// Flips late assignments to OVERDUE in the database (never relies on client logic).
// SUBMITTED / NEEDS_CHANGES are left alone: the ball is with the mentor / the student's revision.
async function sweepOverdue() {
  let total = 0;
  for (let round = 0; round < 20; round += 1) {
    const snap = await db.collection('assignments')
      .where('status', 'in', OVERDUE_FROM).where('deadline', '<', Timestamp.now()).limit(400).get();
    if (snap.empty) break;

    const perStudent = new Map();
    const perMentor = new Map();
    await runBulk((w) => {
      snap.docs.forEach((d) => {
        const a = d.data();
        w.update(d.ref, { status: 'OVERDUE' });
        w.update(db.doc(`students/${a.studentId}`), statsMove(a.status, 'OVERDUE'));
        perStudent.set(a.studentId, [...(perStudent.get(a.studentId) || []), a.taskTitle]);
        if (a.mentorId) {
          const m = perMentor.get(a.mentorId) || { tasks: 0, students: new Set() };
          m.tasks += 1; m.students.add(a.studentName);
          perMentor.set(a.mentorId, m);
        }
      });
    });
    await notifyEach([
      ...[...perStudent].map(([userId, titles]) => ({ userId, type: 'TASK_OVERDUE', title: 'Task overdue', message: `${titles.length} task(s) are now overdue: ${preview(titles)}.` })),
      ...[...perMentor].map(([userId, m]) => ({ userId, type: 'TASK_OVERDUE', title: 'Students have overdue tasks', message: `${m.tasks} task(s) became overdue across ${m.students.size} of your students (${preview([...m.students])}).` })),
    ]);
    total += snap.size;
  }
  if (total) await notifyAdmins({ title: 'Overdue tasks updated', message: `${total} assignment(s) became overdue.`, type: 'SYSTEM' });
  return total;
}

// One reminder per assignment for work due within 24h (the `reminded` flag prevents repeats).
async function sendReminders() {
  const now = new Date();
  const snap = await db.collection('assignments')
    .where('status', 'in', OVERDUE_FROM)
    .where('deadline', '>', Timestamp.fromDate(now))
    .where('deadline', '<=', Timestamp.fromDate(new Date(now.getTime() + DAY)))
    .get();
  const docs = snap.docs.filter((d) => !d.data().reminded);
  if (!docs.length) return 0;

  const perStudent = new Map();
  docs.forEach((d) => perStudent.set(d.data().studentId, [...(perStudent.get(d.data().studentId) || []), d.data().taskTitle]));
  await runBulk((w) => { docs.forEach((d) => w.update(d.ref, { reminded: true })); });
  await notifyEach([...perStudent].map(([userId, titles]) => ({
    userId, type: 'DEADLINE_APPROACHING', title: 'Deadline approaching',
    message: `${titles.length} task(s) due within 24 hours: ${preview(titles)}.`,
  })));
  return perStudent.size;
}

async function runAll() {
  const overdue = await sweepOverdue();
  const reminders = await sendReminders();
  return { overdue, reminders };
}

module.exports = { sweepOverdue, sendReminders, runAll };
