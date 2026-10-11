const fs = require('fs');
const { db, Timestamp } = require('../src/init');
const users = require('../src/services/users');

async function importData() {
  const csv = fs.readFileSync('scripts/real_data.csv', 'utf8');
  // Handle basic CSV parsing line by line
  const lines = csv.split(/\r?\n/).map(l => l.trim()).filter(l => l);
  const headers = lines[0].split(',');
  
  const records = lines.slice(1).map(line => {
    // split by comma but be careful (assuming no quoted commas in this dataset based on visual inspection)
    const row = line.split(',');
    return {
      rollNo: row[1]?.trim(),
      studentName: row[2]?.trim(),
      branch: row[3]?.trim(),
      batch: row[4]?.trim(),
      mentorRollNo: row[5]?.trim(),
      mentorName: row[6]?.trim(),
      leetcode: row[7]?.trim(),
      codeforce: row[8]?.trim(),
      hackerrank: row[9]?.trim(),
      linkedin: row[10]?.trim(),
      github: row[11]?.trim(),
      resume: row[12]?.trim()
    };
  });

  // 1. Wipe existing Emulator Data (Optional but recommended for a clean slate)
  console.log('Cleaning up existing data before importing...');
  const collections = ['batches', 'users', 'mentors', 'students', 'uniques', 'assignments', 'submissions', 'tasks', 'announcements', 'notifications'];
  for (const col of collections) {
    const docs = await db.collection(col).get();
    const batch = db.batch();
    docs.forEach(d => batch.delete(d.ref));
    await batch.commit();
  }
  
  const { auth } = require('../src/init');
  let listUsersResult;
  do {
    listUsersResult = await auth.listUsers(1000, listUsersResult?.pageToken);
    if (listUsersResult.users.length > 0) {
      await auth.deleteUsers(listUsersResult.users.map(u => u.uid));
    }
  } while (listUsersResult.pageToken);
  console.log('Cleared all Auth users.');

  // Create an Admin account
  try {
    await users.createAdmin({ email: 'admin@mentorhub.dev', password: 'Admin@12345', name: 'Super Admin' });
    console.log('Created Admin (admin@mentorhub.dev)');
  } catch (e) {
    if (e.code === 'already-exists') console.log('Admin already exists.');
    else throw e;
  }

  // 2. Collect unique batches
  const batchNames = [...new Set(records.map(r => r.batch).filter(b => b))];
  const batchMap = {}; // name -> id
  for (const bName of batchNames) {
    const bRef = db.collection('batches').doc();
    await bRef.set({
      name: bName,
      academicYear: '2024-25',
      isActive: true,
      startDate: Timestamp.fromDate(new Date()),
      endDate: Timestamp.fromDate(new Date(Date.now() + 365*24*60*60*1000)),
      createdAt: Timestamp.now()
    });
    batchMap[bName] = bRef.id;
    console.log(`Created Batch: ${bName} (${bRef.id})`);
  }

  // 3. Collect unique mentors
  const mentorsMap = {}; // rollNo -> uid
  const uniqueMentors = [];
  const mentorSeen = new Set();
  for (const r of records) {
    if (!r.mentorRollNo) continue;
    if (!mentorSeen.has(r.mentorRollNo)) {
      mentorSeen.add(r.mentorRollNo);
      uniqueMentors.push({
        code: r.mentorRollNo,
        name: r.mentorName,
        batchName: r.batch
      });
    }
  }

  for (const m of uniqueMentors) {
    const email = `${m.code.toLowerCase()}@mentorhub.dev`;
    try {
      const { uid } = await users.createMentor({
        mentorCode: m.code,
        name: m.name,
        email: email,
        batchId: batchMap[m.batchName]
      }, { password: 'Mentor@12345' });
      mentorsMap[m.code] = uid;
      console.log(`Created Mentor: ${m.name} (${m.code})`);
    } catch (e) {
      console.error(`Error creating mentor ${m.code}:`, e.message);
    }
  }

  // 4. Create Students
  let count = 0;
  for (const r of records) {
    if (!r.rollNo) continue;
    const email = `${r.rollNo.toLowerCase()}@mentorhub.dev`;
    try {
      await users.createStudent({
        studentCode: r.rollNo,
        name: r.studentName,
        email: email,
        batchId: batchMap[r.batch],
        mentorId: mentorsMap[r.mentorRollNo] || null,
        leetcode: r.leetcode || null,
        codeforce: r.codeforce || null,
        hackerrank: r.hackerrank || null,
        linkedin: r.linkedin || null,
        github: r.github || null,
        resume: r.resume || null
      }, { password: 'Student@12345' });
      count++;
      if (count % 50 === 0) console.log(`Created ${count} students...`);
    } catch (e) {
      console.error(`Error creating student ${r.rollNo}:`, e.message);
    }
  }

  console.log(`Import Complete! Successfully imported ${count} students, ${uniqueMentors.length} mentors, across ${batchNames.length} batches.`);
  console.log('Logins -> Admin: admin@mentorhub.dev | Mentor: <mentor_roll>@mentorhub.dev | Student: <roll_no>@mentorhub.dev');
  process.exit(0);
}

if (!process.env.FIRESTORE_EMULATOR_HOST && !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('Refusing to run: set the emulator env vars or GOOGLE_APPLICATION_CREDENTIALS.');
  process.exit(1);
}

importData().catch(e => { console.error(e); process.exit(1); });
