const { z } = require('zod');
const { PLATFORMS, DIFFICULTIES } = require('./constants');

const opt = (schema) => z.preprocess((v) => (v === '' || v === null ? undefined : v), schema.optional());
const id = z.string().trim().min(1, 'Required');
const email = z.string().trim().toLowerCase().email('Invalid email address');
const password = z.string().min(8).max(72)
  .regex(/[a-z]/, 'Password needs a lowercase letter')
  .regex(/[A-Z]/, 'Password needs an uppercase letter')
  .regex(/[0-9]/, 'Password needs a number');

const mentorInput = z.object({
  mentorCode: z.string().trim().min(1).max(30),
  name: z.string().trim().min(2).max(100),
  phone: opt(z.string().trim().max(20)),
  email,
  batchId: id,
  password: opt(password),
});
const studentInput = z.object({
  studentCode: z.string().trim().min(1).max(30),
  name: z.string().trim().min(2).max(100),
  phone: opt(z.string().trim().max(20)),
  email,
  batchId: id,
  mentorId: opt(id),
  password: opt(password),
});

const assignTarget = z.discriminatedUnion('type', [
  z.object({ type: z.literal('BATCH') }),
  z.object({ type: z.literal('MENTOR'), mentorId: id }),
  z.object({ type: z.literal('STUDENTS'), studentIds: z.array(id).min(1, 'Select at least one student').max(600) }),
]);

const createTask = z.object({
  title: z.string().trim().min(3).max(200),
  description: opt(z.string().trim().max(5000)),
  platform: z.enum(PLATFORMS),
  problemUrl: z.string().trim().url('Problem URL must be a valid URL'),
  difficulty: z.enum(DIFFICULTIES),
  topic: z.string().trim().min(2).max(60),
  deadline: z.coerce.date().refine((d) => d > new Date(), { message: 'Deadline must be in the future' }),
  batchId: id,
  assignTo: assignTarget.optional(),
});

const submit = z.object({
  assignmentId: id,
  understanding: z.string().trim().min(20, 'Explain the problem in at least 20 characters').max(5000),
  approach: z.string().trim().min(20, 'Describe your approach in at least 20 characters').max(5000),
  timeComplexity: z.string().trim().min(2, 'Time complexity is required').max(100),
  spaceComplexity: z.string().trim().min(2, 'Space complexity is required').max(100),
  solutionUrl: opt(z.string().trim().url('Solution URL must be a valid URL')),
  code: opt(z.string().max(20000)),
});

const review = z.object({
  submissionId: id,
  decision: z.enum(['APPROVED', 'NEEDS_CHANGES']),
  feedback: opt(z.string().trim().max(3000)),
}).refine((v) => v.decision !== 'NEEDS_CHANGES' || (v.feedback && v.feedback.length >= 5), {
  message: 'Feedback (at least 5 characters) is required when requesting changes', path: ['feedback'],
});

const announcement = z.object({
  title: z.string().trim().min(3).max(150),
  message: z.string().trim().min(3).max(3000),
  targetType: z.enum(['ALL', 'MENTORS', 'STUDENTS', 'MENTOR_STUDENTS']),
  batchId: opt(id),
  mentorId: opt(id),
});

// Row shapes for bulk import (same columns as the CSV templates)
const text = (label) => z.string({ required_error: `${label} is required` }).trim().min(1, `${label} is required`);
const mentorRow = z.object({
  mentor_id: text('mentor_id').max(30), name: text('name').min(2).max(100), phone: opt(z.string().trim().max(20)),
  email: text('email').toLowerCase().pipe(z.string().email('email is invalid')), batch: text('batch'),
});
const studentRow = z.object({
  student_id: text('student_id').max(30), name: text('name').min(2).max(100), phone: opt(z.string().trim().max(20)),
  email: text('email').toLowerCase().pipe(z.string().email('email is invalid')), mentor_id: text('mentor_id'), batch: text('batch'),
});

const submitWeekly = z.object({
  batchId: id,
  weekId: z.string().trim().min(1),
  claimedCount: z.coerce.number().int().min(0, 'Count must be non-negative'),
  problemName: opt(z.string().trim().max(200)),
  problemUrl: opt(z.string().trim().max(1000)),
  approach: opt(z.string().trim().max(5000)),
});

const verifyWeekly = z.object({
  submissionId: opt(z.string().trim()),
  batchId: opt(id),
  weekId: opt(z.string().trim()),
  juniorUid: opt(id),
  verifiedCount: z.coerce.number().int().min(0, 'Count must be non-negative'),
  verificationStatus: z.enum(['VERIFIED', 'DOUBTFUL', 'NOT_CHECKED']),
  seriousness: z.enum(['HIGH', 'MEDIUM', 'LOW']),
  remarks: opt(z.string().trim().max(3000)),
});

const scheduleMock = z.object({
  batchId: id,
  weekId: z.string().trim().min(1),
  juniorUid: id,
  scheduledAt: z.string().trim().min(1),
  seniorUid: opt(id),
  topic: opt(z.string().trim().max(250)),
  meetingLink: opt(z.string().trim().max(500)),
  durationMinutes: opt(z.coerce.number().int().min(5).max(300)),
  notes: opt(z.string().trim().max(3000)),
  status: opt(z.enum(['NOT_PLANNED', 'SCHEDULED', 'COMPLETED', 'MISSED', 'CANCELLED'])),
});

const evaluateMock = z.object({
  batchId: id,
  weekId: z.string().trim().min(1),
  juniorUid: id,
  score10: z.coerce.number().min(0).max(10, 'Overall score must be 0-10'),
  technical5: z.coerce.number().min(0).max(5, 'Technical score must be 0-5'),
  communication5: z.coerce.number().min(0).max(5, 'Communication score must be 0-5'),
  problemSolving5: z.coerce.number().min(0).max(5, 'Problem solving score must be 0-5'),
  recommendation: opt(z.string().trim().max(500)),
  notes: opt(z.string().trim().max(3000)),
  status: opt(z.enum(['NOT_PLANNED', 'SCHEDULED', 'COMPLETED', 'MISSED'])),
});

const updateWeeklyConfig = z.object({
  batchId: id,
  weeks: z.array(z.object({
    weekId: opt(z.string().trim()),
    label: opt(z.string().trim()),
    targetCumulative: z.coerce.number().int().min(0),
    startsAt: opt(z.string().trim()),
    order: opt(z.coerce.number().int()),
  })).min(1),
});

const optUrl = opt(z.string().trim().url('Must be a valid URL'));

const updateProfileLinks = z.object({
  leetcodeUrl: optUrl,
  codeforcesUrl: optUrl,
  hackerRankUrl: optUrl,
  linkedInUrl: optUrl,
  gitHubUrl: optUrl,
  resumeUrl: optUrl,
  phone: opt(z.string().trim().max(20)),
});

const bulkImportCssp = z.object({
  batchId: id,
  records: z.array(z.record(z.any())).min(1).max(1000),
  fileName: opt(z.string().trim().max(100)),
});

const createAdminInput = z.object({
  email,
  password,
  name: opt(z.string().trim().min(2).max(100)),
  batchIds: opt(z.array(z.string().trim())),
});

module.exports = {
  mentorInput, studentInput, assignTarget, createTask, submit, review, announcement, mentorRow, studentRow,
  setActive: z.object({ uid: id, isActive: z.boolean() }),
  uidOnly: z.object({ uid: id }),
  updateStudentMentor: z.object({ studentId: id, mentorId: z.string().trim().min(1).nullable() }),
  assignTask: z.object({ taskId: id, assignTo: assignTarget }),
  taskId: z.object({ taskId: id }),
  assignmentId: z.object({ assignmentId: id }),
  importRows: z.object({ kind: z.enum(['mentors', 'students']), rows: z.array(z.record(z.any())).min(1).max(100), startRow: z.number().int().min(2).optional() }),
  submitWeekly,
  verifyWeekly,
  scheduleMock,
  evaluateMock,
  updateWeeklyConfig,
  updateProfileLinks,
  bulkImportCssp,
  createAdminInput,
};
