// Development seed: 1 batch, 1 admin, 3 mentors, 15 students, 10 tasks, 150 assignments in mixed states.
// Run against the emulators (recommended):
//   firebase emulators:start --only auth,firestore      (terminal 1, from the repo root)
//   FIRESTORE_EMULATOR_HOST=localhost:8080 FIREBASE_AUTH_EMULATOR_HOST=localhost:9099 GCLOUD_PROJECT=demo-mentorhub npm run seed
const { db, Timestamp } = require('../src/init');
const users = require('../src/services/users');
const tasks = require('../src/services/tasks');
const assignments = require('../src/services/assignments');
const { createAnnouncement } = require('../src/services/announcements');
const jobs = require('../src/services/jobs');

if (!process.env.FIRESTORE_EMULATOR_HOST && !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('Refusing to run: set the emulator env vars or GOOGLE_APPLICATION_CREDENTIALS.');
  process.exit(1);
}

const DAY = 86400000;
const inDays = (d) => new Date(Date.now() + d * DAY);
const MENTORS = [['M001', 'Anita Rao'], ['M002', 'Vikram Sharma'], ['M003', 'Neha Kulkarni']];
const NAMES = ['Aarav Reddy', 'Diya Patel', 'Rohan Gupta', 'Sneha Iyer', 'Karthik Nair', 'Meera Joshi', 'Arjun Verma', 'Ishita Das',
  'Siddharth Rao', 'Pooja Menon', 'Aditya Kapoor', 'Lakshmi Pillai', 'Varun Shetty', 'Tanvi Desai', 'Harsh Mehta'];
const TASKS = [
  ['Two Sum', 'EASY', 'Arrays', 'two-sum'], ['Valid Parentheses', 'EASY', 'Stacks', 'valid-parentheses'],
  ['Reverse Linked List', 'EASY', 'Linked Lists', 'reverse-linked-list'], ['Climbing Stairs', 'EASY', 'Dynamic Programming', 'climbing-stairs'],
  ['House Robber', 'MEDIUM', 'Dynamic Programming', 'house-robber'], ['Coin Change', 'MEDIUM', 'Dynamic Programming', 'coin-change'],
  ['Binary Search', 'EASY', 'Binary Search', 'binary-search'], ['Number of Islands', 'MEDIUM', 'Graphs', 'number-of-islands'],
  ['Merge Intervals', 'MEDIUM', 'Arrays', 'merge-intervals'], ['Trapping Rain Water', 'HARD', 'Two Pointers', 'trapping-rain-water'],
];

async function main() {
  const batchRef = db.collection('batches').doc();
  await batchRef.set({
    name: 'Product Batch 2026', academicYear: '2026-27', isActive: true,
    startDate: Timestamp.fromDate(inDays(-30)), endDate: Timestamp.fromDate(inDays(150)), createdAt: Timestamp.now(),
  });
  const batchId = batchRef.id;

  const admin = await users.createAdmin({ email: 'admin@mentorhub.dev', password: 'Admin@12345' });

  const mentors = [];
  for (const [code, name] of MENTORS) {
    const { uid } = await users.createMentor({ mentorCode: code, name, email: `${code.toLowerCase()}@mentorhub.dev`, batchId }, { password: 'Mentor@12345' });
    mentors.push({ uid, code });
  }
  const students = [];
  let n = 1;
  for (const m of mentors) {
    for (let i = 0; i < 5; i += 1) {
      const code = `S${String(n).padStart(3, '0')}`;
      const { uid } = await users.createStudent({ studentCode: code, name: NAMES[n - 1], email: `${code.toLowerCase()}@mentorhub.dev`, batchId, mentorId: m.uid }, { password: 'Student@12345' });
      students.push({ uid, mentorUid: m.uid });
      n += 1;
    }
  }

  const taskIds = [];
  for (const [i, [title, difficulty, topic, slug]] of TASKS.entries()) {
    const { taskId } = await tasks.createTask(admin.uid, {
      title, difficulty, topic, platform: 'LEETCODE', batchId, problemUrl: `https://leetcode.com/problems/${slug}/`,
      description: `Solve "${title}" and explain your thinking in the submission form.`,
      deadline: inDays(i < 3 ? -2 + i : i * 2), // first three are already past due
      assignTo: { type: 'BATCH' },
    });
    taskIds.push(taskId);
  }

  const answer = (title) => ({
    understanding: `We need to solve ${title} efficiently for the given constraints.`,
    approach: 'Break the problem into smaller subproblems and track the state needed to avoid repeated work.',
    timeComplexity: 'O(n)', spaceComplexity: 'O(n)', solutionUrl: 'https://leetcode.com/submissions/detail/123456/',
    code: '// sample solution\nfunction solve(input) {\n  return input;\n}',
  });

  for (const [si, s] of students.entries()) {
    for (const [ti, taskId] of taskIds.entries()) {
      const id = `${taskId}_${s.uid}`;
      const roll = (si * 7 + ti * 3) % 10;
      const title = TASKS[ti][0];
      if (ti < 3) {
        if (roll >= 8) continue; // stays ASSIGNED -> becomes OVERDUE in the sweep
        await assignments.submitAssignment(s.uid, { assignmentId: id, ...answer(title) });
        if (roll < 5) await assignments.reviewSubmission(s.mentorUid, { submissionId: id, decision: 'APPROVED', feedback: 'Clear explanation. Nicely done.' });
        else if (roll === 7) await assignments.reviewSubmission(s.mentorUid, { submissionId: id, decision: 'NEEDS_CHANGES', feedback: 'Your approach is correct, but explain why a HashMap gives O(1) average lookup.' });
      } else if (ti < 5 && roll < 3) {
        await assignments.startAssignment(s.uid, id);
      }
    }
  }

  // Super Admin account (Blueprint Section 2 & 3)
  try {
    const superUser = await users.createAuthUser({
      email: 'superadmin@mentorhub.dev',
      password: 'SuperAdmin@12345',
      role: 'SUPER_ADMIN',
      name: 'Super Administrator',
    });
    await db.doc(`users/${superUser.uid}`).set({
      email: 'superadmin@mentorhub.dev',
      role: 'SUPER_ADMIN',
      name: 'Super Administrator',
      isActive: true,
      mustChangePassword: false,
      batchId: null,
      createdAt: Timestamp.now(),
    });
  } catch (_) {}

  // CSSP 12-Week Milestone Targets (Blueprint Section 4)
  const targets = [98, 111, 141, 156, 170, 184, 207, 207, 207, 207, 207, 207];
  const startDate = new Date('2026-10-05T00:00:00Z');
  for (let i = 0; i < 12; i++) {
    const weekId = `W${i + 1}`;
    const startsAt = new Date(startDate.getTime() + i * 7 * 86400000);
    await db.doc(`weeks/${batchId}_${weekId}`).set({
      batchId,
      weekId,
      label: `Week ${i + 1}`,
      order: i + 1,
      targetCumulative: targets[i],
      startsAt: Timestamp.fromDate(startsAt),
      createdAt: Timestamp.now(),
    });
  }

  // Seed portfolio links and CSSP assignments for students
  for (const [idx, s] of students.entries()) {
    const code = `S${String(idx + 1).padStart(3, '0')}`;
    const links = {
      leetcode: `https://leetcode.com/u/student_${code.toLowerCase()}`,
      codeforce: `https://codeforces.com/profile/student_${code.toLowerCase()}`,
      hackerrank: `https://hackerrank.com/student_${code.toLowerCase()}`,
      linkedin: `https://linkedin.com/in/student-${code.toLowerCase()}`,
      github: `https://github.com/student-${code.toLowerCase()}`,
      resume: `https://example.com/resumes/${code.toLowerCase()}.pdf`,
      phone: `+91 98765 432${String(idx).padStart(2, '0')}`,
    };
    await db.doc(`students/${s.uid}`).set(links, { merge: true });
    await db.doc(`profiles/${s.uid}`).set(links, { merge: true });

    // CSSP pairing doc
    await db.doc(`assignments/${batchId}_${s.uid}`).set({
      batchId,
      seniorUid: s.mentorUid,
      mentorId: s.mentorUid,
      juniorUid: s.uid,
      studentId: s.uid,
      effectiveFrom: Timestamp.now(),
      active: true,
    }, { merge: true });
  }

  // Seed sample CSSP W1 submissions & verifications for the first student
  const sampleStudent = students[0];
  const subId = `${batchId}_W1_${sampleStudent.uid}`;
  await db.doc(`submissions/${subId}`).set({
    batchId,
    weekId: 'W1',
    juniorUid: sampleStudent.uid,
    studentId: sampleStudent.uid,
    seniorUid: sampleStudent.mentorUid,
    mentorId: sampleStudent.mentorUid,
    claimedCount: 104,
    problemName: 'Two Sum',
    problemUrl: 'https://leetcode.com/problems/two-sum/',
    approach: 'One-pass hash table mapping complements to indices.',
    status: 'VERIFIED',
    verifiedCount: 104,
    verificationStatus: 'VERIFIED',
    seriousness: 'HIGH',
    remarks: 'Live explanation was clear; verified 104 solved on LeetCode profile.',
    submittedAt: Timestamp.now(),
    checkedAt: Timestamp.now(),
    checkedByUid: sampleStudent.mentorUid,
    reviewedBy: sampleStudent.mentorUid,
    reviewedAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  });
  await db.doc(`verifications/${subId}`).set({
    submissionId: subId,
    batchId,
    weekId: 'W1',
    juniorUid: sampleStudent.uid,
    verifiedCount: 104,
    verificationStatus: 'VERIFIED',
    seriousness: 'HIGH',
    remarks: 'Live explanation was clear; verified 104 solved on LeetCode profile.',
    checkedAt: Timestamp.now(),
    checkedByUid: sampleStudent.mentorUid,
  });

  // Seed sample mock interview
  const mockId = `${batchId}_W1_${sampleStudent.uid}`;
  await db.doc(`mocks/${mockId}`).set({
    batchId,
    weekId: 'W1',
    juniorUid: sampleStudent.uid,
    seniorUid: sampleStudent.mentorUid,
    evaluatorUid: sampleStudent.mentorUid,
    status: 'COMPLETED',
    score10: 9,
    technical5: 4.5,
    communication5: 4.5,
    problemSolving5: 4.5,
    recommendation: 'Excellent performance in DSA round.',
    notes: 'Strong understanding of array and hash table patterns.',
    scheduledAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  });

  // Audit log entry
  await db.collection('auditLogs').add({
    actorUid: 'system',
    actorRole: 'SYSTEM',
    action: 'SEED_INITIAL_DATA',
    targetPath: `batches/${batchId}`,
    timestamp: Timestamp.now(),
    changedFields: { batchId, weeksCount: 12, studentsCount: students.length },
  });

  await jobs.sweepOverdue();
  await createAnnouncement({ uid: admin.uid, role: 'ADMIN' }, { title: 'Welcome to CSSP MentorHub', message: 'Your CSSP Track & Product Batch journey starts now. Check your tasks and submit weekly progress on time.', targetType: 'ALL', batchId });

  console.log('Seeded: 1 superadmin, 1 admin, 3 mentors, 15 students, 12 CSSP weeks, 10 tasks, 150 assignments');
  console.log('Logins -> superadmin@mentorhub.dev / SuperAdmin@12345 | admin@mentorhub.dev / Admin@12345 | m001@mentorhub.dev / Mentor@12345 | s001@mentorhub.dev / Student@12345');
}

main().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });
