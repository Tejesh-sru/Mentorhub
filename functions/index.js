const { setGlobalOptions } = require('firebase-functions/v2');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { ZodError } = require('zod');
const { REGION } = require('./src/constants');
const v = require('./src/validators');
const users = require('./src/services/users');
const tasks = require('./src/services/tasks');
const assignments = require('./src/services/assignments');
const { createAnnouncement } = require('./src/services/announcements');
const { importRows } = require('./src/services/importer');
const jobs = require('./src/services/jobs');
const cssp = require('./src/services/cssp');

setGlobalOptions({ region: REGION, maxInstances: 10 });

const toHttpsError = (e) => {
  if (e instanceof HttpsError) return e;
  if (e instanceof ZodError) return new HttpsError('invalid-argument', e.issues.map((i) => i.message).join('; '));
  if (e && e.isAppError) return new HttpsError(e.code, e.message);
  console.error(e);
  return new HttpsError('internal', 'Something went wrong. Please try again.');
};

// Every callable: authenticated -> role allowed -> input validated (zod) -> business logic.
// The role comes from the signed custom claim (set by the Admin SDK), never from client-supplied data.
const callable = (roles, schema, handler, options = {}) => onCall(options, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in');
  const role = request.auth.token.role;
  if (!roles.includes(role)) throw new HttpsError('permission-denied', 'You do not have permission to perform this action');
  try {
    const input = schema ? schema.parse(request.data ?? {}) : (request.data ?? {});
    return await handler({ uid: request.auth.uid, role, input });
  } catch (e) {
    throw toHttpsError(e);
  }
});

const SUPER_ADMIN = ['SUPER_ADMIN'];
const ADMIN = ['ADMIN', 'SUPER_ADMIN'];
const MENTOR = ['MENTOR', 'ADMIN', 'SUPER_ADMIN'];
const STUDENT = ['STUDENT'];
const ANY = ['SUPER_ADMIN', 'ADMIN', 'MENTOR', 'STUDENT'];

// ── people ──
exports.createMentor = callable(ADMIN, v.mentorInput, ({ input }) => users.createMentor(input));
exports.createStudent = callable(ADMIN, v.studentInput, ({ input }) => users.createStudent(input));
exports.setUserActive = callable(ADMIN, v.setActive, async ({ uid, input }) => { await users.setActive(uid, input.uid, input.isActive); return { ok: true }; });
exports.resetUserPassword = callable(ADMIN, v.uidOnly, async ({ input }) => { await users.resetPassword(input.uid); return { ok: true }; });
exports.updateStudentMentor = callable(ADMIN, v.updateStudentMentor, async ({ input }) => { await users.updateStudentMentor(input.studentId, input.mentorId); return { ok: true }; }, { timeoutSeconds: 120 });
// Called by the app after the user re-authenticated and changed their password via the Firebase Auth SDK.
exports.markPasswordChanged = callable(ANY, null, async ({ uid }) => { await users.markPasswordChanged(uid); return { ok: true }; });

// ── tasks ──
exports.createTask = callable(ADMIN, v.createTask, ({ uid, input }) => tasks.createTask(uid, input), { timeoutSeconds: 300, memory: '512MiB' });
exports.assignTask = callable(ADMIN, v.assignTask, ({ input }) => tasks.assignTask(input.taskId, input.assignTo), { timeoutSeconds: 300, memory: '512MiB' });
exports.deleteTask = callable(ADMIN, v.taskId, ({ input }) => tasks.deleteTask(input.taskId), { timeoutSeconds: 300 });

// ── student workflow ──
exports.startAssignment = callable(['STUDENT'], v.assignmentId, async ({ uid, input }) => { await assignments.startAssignment(uid, input.assignmentId); return { ok: true }; });
exports.submitAssignment = callable(['STUDENT'], v.submit, ({ uid, input }) => assignments.submitAssignment(uid, input));

// ── mentor workflow ──
exports.reviewSubmission = callable(['MENTOR'], v.review, async ({ uid, input }) => { await assignments.reviewSubmission(uid, input); return { ok: true }; });

// ── announcements / import / maintenance ──
exports.createAnnouncement = callable(['ADMIN', 'MENTOR'], v.announcement, ({ uid, role, input }) => createAnnouncement({ uid, role }, input), { timeoutSeconds: 120 });
exports.importRows = callable(ADMIN, v.importRows, ({ input }) => importRows(input), { timeoutSeconds: 300 });
exports.recomputeStats = callable(ADMIN, null, () => users.recomputeStats(), { timeoutSeconds: 300, memory: '512MiB' });
exports.runJobs = callable(ADMIN, null, () => jobs.runAll(), { timeoutSeconds: 300 });

// ── scheduled: overdue marking + deadline reminders every 10 minutes ──
exports.overdueSweep = onSchedule(
  { schedule: 'every 10 minutes', timeZone: 'Asia/Kolkata', timeoutSeconds: 300, memory: '512MiB' },
  async () => {
    const r = await jobs.runAll();
    if (r.overdue || r.reminders) console.log(`[jobs] overdue=${r.overdue} reminders=${r.reminders}`);
  },
);

// ── CSSP Mentor Tracker workflows ──
exports.submitWeeklyProgress = callable(['STUDENT'], v.submitWeekly, ({ uid, input }) => cssp.submitWeeklyProgress(uid, input));
exports.verifyWeeklyProgress = callable(['MENTOR', 'ADMIN', 'SUPER_ADMIN'], v.verifyWeekly, ({ uid, input }) => cssp.verifyWeeklyProgress(uid, input));
exports.scheduleMock = callable(['MENTOR', 'ADMIN', 'SUPER_ADMIN'], v.scheduleMock, ({ uid, input }) => cssp.scheduleMock(uid, input));
exports.evaluateMock = callable(['MENTOR', 'ADMIN', 'SUPER_ADMIN'], v.evaluateMock, ({ uid, input }) => cssp.evaluateMock(uid, input));
exports.updateWeeklyConfig = callable(ADMIN, v.updateWeeklyConfig, ({ uid, input }) => cssp.updateWeeklyConfig(uid, input));
exports.updateProfileLinks = callable(ANY, v.updateProfileLinks, ({ uid, input }) => cssp.updateProfileLinks(uid, input));
exports.bulkImportStudentsCssp = callable(ADMIN, v.bulkImportCssp, ({ uid, input }) => cssp.bulkImportStudentsCssp(uid, input), { timeoutSeconds: 300, memory: '512MiB' });
exports.createAdminAccount = callable(ADMIN, v.createAdminInput, ({ uid, input }) => cssp.createAdminAccount(uid, input));
