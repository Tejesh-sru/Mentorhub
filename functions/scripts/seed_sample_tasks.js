const { db, Timestamp } = require('../src/init');
const tasks = require('../src/services/tasks');
const assignments = require('../src/services/assignments');
const jobs = require('../src/services/jobs');

const DAY = 86400000;
const inDays = (d) => new Date(Date.now() + d * DAY);

const SAMPLE_TASKS = [
  { title: 'Two Sum', difficulty: 'EASY', topic: 'Arrays & Hashing', platform: 'LEETCODE', slug: 'two-sum', desc: 'Find two indices whose values sum up to the target.' },
  { title: 'Valid Parentheses', difficulty: 'EASY', topic: 'Stacks', platform: 'LEETCODE', slug: 'valid-parentheses', desc: 'Check if brackets are properly closed and nested.' },
  { title: 'Reverse Linked List', difficulty: 'EASY', topic: 'Linked Lists', platform: 'LEETCODE', slug: 'reverse-linked-list', desc: 'Reverse a singly-linked list iteratively or recursively.' },
  { title: 'Container With Most Water', difficulty: 'MEDIUM', topic: 'Two Pointers', platform: 'LEETCODE', slug: 'container-with-most-water', desc: 'Find two lines that together with the x-axis form a container containing the most water.' },
  { title: 'House Robber', difficulty: 'MEDIUM', topic: 'Dynamic Programming', platform: 'LEETCODE', slug: 'house-robber', desc: 'Maximize stolen money without alerting police by robbing adjacent houses.' },
  { title: 'Coin Change', difficulty: 'MEDIUM', topic: 'Dynamic Programming', platform: 'LEETCODE', slug: 'coin-change', desc: 'Find the minimum coins needed to make up the given amount.' },
  { title: 'Number of Islands', difficulty: 'MEDIUM', topic: 'Graphs (BFS/DFS)', platform: 'LEETCODE', slug: 'number-of-islands', desc: 'Count the number of connected components in a 2D binary grid.' },
  { title: 'Binary Search', difficulty: 'EASY', topic: 'Binary Search', platform: 'LEETCODE', slug: 'binary-search', desc: 'Implement O(log n) binary search in a sorted array.' },
];

async function seedTasks() {
  console.log('Seeding sample tasks and assignments for all batches...');

  // 1. Get all batches
  const batchesSnap = await db.collection('batches').get();
  if (batchesSnap.empty) {
    console.log('No batches found to seed tasks.');
    return;
  }

  // 2. Get admin
  const adminSnap = await db.collection('users').where('role', '==', 'ADMIN').limit(1).get();
  const adminUid = adminSnap.empty ? 'admin' : adminSnap.docs[0].id;

  // 3. For each batch, create the tasks
  for (const bDoc of batchesSnap.docs) {
    const batchId = bDoc.id;
    const batchName = bDoc.data().name;
    console.log(`Creating tasks for batch: ${batchName}...`);

    for (let i = 0; i < SAMPLE_TASKS.length; i++) {
      const t = SAMPLE_TASKS[i];
      const deadline = inDays(i < 3 ? -2 + i : (i + 1) * 3);

      try {
        await tasks.createTask(adminUid, {
          title: t.title,
          difficulty: t.difficulty,
          topic: t.topic,
          platform: t.platform,
          batchId: batchId,
          problemUrl: `https://leetcode.com/problems/${t.slug}/`,
          description: t.desc,
          deadline: deadline,
          assignTo: { type: 'BATCH' },
        });
      } catch (err) {
        console.error(`Error creating task ${t.title} for batch ${batchName}:`, err.message);
      }
    }
  }

  // 4. Create some submissions for the first 30 students to give them realistic Done & Pending data
  const studentsSnap = await db.collection('students').limit(30).get();
  console.log(`Adding realistic submissions and progress for ${studentsSnap.size} students...`);

  for (const [sIndex, sDoc] of studentsSnap.docs.entries()) {
    const student = sDoc.data();
    const studentUid = sDoc.id;
    const mentorId = student.mentorId;

    // Get assignments for this student
    const assignSnap = await db.collection('assignments').where('studentId', '==', studentUid).get();

    for (const [aIndex, aDoc] of assignSnap.docs.entries()) {
      const assignmentId = aDoc.id;
      const taskTitle = aDoc.data().taskTitle;

      // Seed varied states:
      // aIndex 0 -> COMPLETED (Approved)
      // aIndex 1 -> COMPLETED (Approved)
      // aIndex 2 -> SUBMITTED (Awaiting Review)
      // aIndex 3 -> IN_PROGRESS
      // aIndex >= 4 -> ASSIGNED (Pending)
      if (aIndex === 0 || aIndex === 1) {
        await assignments.submitAssignment(studentUid, {
          assignmentId: assignmentId,
          understanding: `Understood problem ${taskTitle}. Need to optimize using standard algorithmic techniques.`,
          approach: 'Used two-pointer or hash map technique to achieve optimal time complexity.',
          timeComplexity: 'O(n)',
          spaceComplexity: 'O(1)',
          solutionUrl: `https://leetcode.com/submissions/detail/${100000 + aIndex}/`,
          code: `// Solution for ${taskTitle}\nfunction solve(nums, target) {\n  const map = new Map();\n  for (let i = 0; i < nums.length; i++) {\n    const comp = target - nums[i];\n    if (map.has(comp)) return [map.get(comp), i];\n    map.set(nums[i], i);\n  }\n  return [];\n}`,
        });

        if (mentorId) {
          await assignments.reviewSubmission(mentorId, {
            submissionId: assignmentId,
            decision: 'APPROVED',
            feedback: 'Great optimal O(n) solution! Code is clean and well-structured.',
          });
        }
      } else if (aIndex === 2) {
        // Awaiting review
        await assignments.submitAssignment(studentUid, {
          assignmentId: assignmentId,
          understanding: `Analyzed edge cases and constraints for ${taskTitle}.`,
          approach: 'Implemented iterative solution with stack/pointer tracking.',
          timeComplexity: 'O(n)',
          spaceComplexity: 'O(n)',
          solutionUrl: `https://leetcode.com/submissions/detail/${200000 + aIndex}/`,
          code: `// Solution for ${taskTitle}\nclass Solution {\npublic:\n  bool isValid(string s) {\n    stack<char> st;\n    for (char c : s) {\n      if (c == '(' || c == '{' || c == '[') st.push(c);\n      else {\n        if (st.empty()) return false;\n        if (c == ')' && st.top() != '(') return false;\n        if (c == '}' && st.top() != '{') return false;\n        if (c == ']' && st.top() != '[') return false;\n        st.pop();\n      }\n    }\n    return st.empty();\n  }\n};`,
        });
      } else if (aIndex === 3) {
        await assignments.startAssignment(studentUid, assignmentId);
      }
    }
  }

  // Sweep overdue
  await jobs.sweepOverdue().catch(() => {});

  console.log('Sample tasks and assignments seeded successfully!');
}

seedTasks().then(() => process.exit(0)).catch((e) => {
  console.error('Error seeding tasks:', e);
  process.exit(1);
});
