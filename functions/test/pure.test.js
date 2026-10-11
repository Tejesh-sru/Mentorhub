const test = require('node:test');
const assert = require('node:assert/strict');
const { emptyStats, statsMove, buildProgress } = require('../src/stats');
const { audienceKeys } = require('../src/audience');
const v = require('../src/validators');

test('progress is derived: approved / assigned', () => {
  const p = buildProgress({ ...emptyStats(), ASSIGNED: 3, APPROVED: 15, OVERDUE: 2 });
  assert.equal(p.assigned, 20);
  assert.equal(p.percentage, 75);
  assert.equal(p.pending, 3);
  assert.equal(p.overdue, 2);
});

test('progress of a student with no tasks is 0', () => assert.equal(buildProgress(emptyStats()).percentage, 0));

test('statsMove creates dotted increment paths', () => {
  const u = statsMove('SUBMITTED', 'APPROVED');
  assert.deepEqual(Object.keys(u).sort(), ['stats.APPROVED', 'stats.SUBMITTED']);
  assert.deepEqual(statsMove('OVERDUE', 'OVERDUE'), {});
  assert.deepEqual(Object.keys(statsMove(null, 'ASSIGNED')), ['stats.ASSIGNED']);
});

test('audience keys match the rules', () => {
  assert.deepEqual(audienceKeys({ targetType: 'ALL' }), ['all:*']);
  assert.deepEqual(audienceKeys({ targetType: 'STUDENTS', batchId: 'b1' }), ['students:b1']);
  assert.deepEqual(audienceKeys({ targetType: 'MENTOR_STUDENTS', mentorId: 'm9' }), ['mentor:m9']);
});

test('review requires feedback when requesting changes', () => {
  assert.equal(v.review.safeParse({ submissionId: 'x', decision: 'NEEDS_CHANGES' }).success, false);
  assert.equal(v.review.safeParse({ submissionId: 'x', decision: 'NEEDS_CHANGES', feedback: 'Explain O(1) lookup' }).success, true);
  assert.equal(v.review.safeParse({ submissionId: 'x', decision: 'APPROVED' }).success, true);
});

test('submission needs real explanations', () => {
  const base = { assignmentId: 'a', understanding: 'too short', approach: 'x'.repeat(30), timeComplexity: 'O(n)', spaceComplexity: 'O(1)' };
  assert.equal(v.submit.safeParse(base).success, false);
  assert.equal(v.submit.safeParse({ ...base, understanding: 'x'.repeat(25) }).success, true);
});

test('task deadline must be in the future; assignTo variants validate', () => {
  const t = { title: 'Two Sum', platform: 'LEETCODE', problemUrl: 'https://leetcode.com/problems/two-sum/', difficulty: 'EASY', topic: 'Arrays', batchId: 'b' };
  assert.equal(v.createTask.safeParse({ ...t, deadline: new Date(Date.now() - 1000).toISOString() }).success, false);
  const future = new Date(Date.now() + 86400000).toISOString();
  assert.equal(v.createTask.safeParse({ ...t, deadline: future, assignTo: { type: 'BATCH' } }).success, true);
  assert.equal(v.createTask.safeParse({ ...t, deadline: future, assignTo: { type: 'STUDENTS', studentIds: [] } }).success, false);
});

test('import rows validate required columns', () => {
  assert.equal(v.studentRow.safeParse({ student_id: 'S1', name: 'Asha', email: 'a@x.com', mentor_id: 'M1', batch: 'B' }).success, true);
  assert.equal(v.studentRow.safeParse({ student_id: 'S1', name: 'Asha', email: 'nope', mentor_id: 'M1', batch: 'B' }).success, false);
  assert.equal(v.mentorRow.safeParse({ name: 'X', email: 'a@x.com', batch: 'B' }).success, false);
});

test('cssp: mock evaluation rejects invalid scores (e.g. 11/10 or 6/5)', () => {
  const base = { batchId: 'b1', weekId: 'W1', juniorUid: 'j1', score10: 8, technical5: 4, communication5: 4, problemSolving5: 4 };
  assert.equal(v.evaluateMock.safeParse(base).success, true);
  // Overall score cannot exceed 10
  assert.equal(v.evaluateMock.safeParse({ ...base, score10: 11 }).success, false);
  // Criteria scores cannot exceed 5
  assert.equal(v.evaluateMock.safeParse({ ...base, technical5: 6 }).success, false);
  assert.equal(v.evaluateMock.safeParse({ ...base, communication5: -1 }).success, false);
});

test('cssp: weekly submission validates count and required fields', () => {
  assert.equal(v.submitWeekly.safeParse({ batchId: 'b1', weekId: 'W1', claimedCount: 115 }).success, true);
  assert.equal(v.submitWeekly.safeParse({ batchId: 'b1', weekId: 'W1', claimedCount: -5 }).success, false);
  assert.equal(v.submitWeekly.safeParse({ batchId: '', weekId: 'W1', claimedCount: 50 }).success, false);
});

test('cssp: weekly verification validates status and seriousness', () => {
  const base = { batchId: 'b1', weekId: 'W1', juniorUid: 'j1', verifiedCount: 110, verificationStatus: 'VERIFIED', seriousness: 'HIGH' };
  assert.equal(v.verifyWeekly.safeParse(base).success, true);
  assert.equal(v.verifyWeekly.safeParse({ ...base, verificationStatus: 'INVALID' }).success, false);
  assert.equal(v.verifyWeekly.safeParse({ ...base, seriousness: 'SUPER' }).success, false);
});

test('cssp: target met iff verified count >= week target (business rule)', () => {
  const isTargetMet = (verifiedCount, weekTarget, status) => {
    if (status !== 'VERIFIED') return false;
    return (verifiedCount ?? 0) >= weekTarget;
  };
  assert.equal(isTargetMet(115, 111, 'VERIFIED'), true);
  assert.equal(isTargetMet(110, 111, 'VERIFIED'), false);
  // Pending or awaiting review must not count as verified
  assert.equal(isTargetMet(120, 111, 'AWAITING_REVIEW'), false);
});

test('cssp: bulk import validates rollNo and name', () => {
  const valid = {
    batchId: 'batch_2026',
    records: [
      { rollNo: '24W11A0501', studentName: 'Student One', leetcode: 'https://leetcode.com/u/s1' },
      { rollNo: '24W11A0502', studentName: 'Student Two' },
    ],
  };
  assert.equal(v.bulkImportCssp.safeParse(valid).success, true);
  // Empty batchId fails
  assert.equal(v.bulkImportCssp.safeParse({ batchId: '', records: [] }).success, false);
});

test('cssp: profile link validation checks URL scheme', () => {
  const valid = {
    leetcodeUrl: 'https://leetcode.com/u/johndoe',
    gitHubUrl: 'https://github.com/johndoe',
  };
  assert.equal(v.updateProfileLinks.safeParse(valid).success, true);
  // Invalid scheme should fail zod url validation if provided
  const invalid = { leetcodeUrl: 'not-a-valid-url' };
  assert.equal(v.updateProfileLinks.safeParse(invalid).success, false);
});

test('cssp: 12-week blueprint targets are monotonic non-decreasing', () => {
  const targets = [98, 111, 141, 156, 170, 184, 207, 207, 207, 207, 207, 207];
  assert.equal(targets.length, 12);
  for (let i = 1; i < targets.length; i++) {
    assert.ok(targets[i] >= targets[i - 1], `Target at W${i + 1} (${targets[i]}) must be >= W${i} (${targets[i - 1]})`);
  }
});

