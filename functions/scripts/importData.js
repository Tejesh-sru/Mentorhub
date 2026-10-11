const fs = require('fs');
const xlsx = require('xlsx');
const { db, Timestamp } = require('../src/init');
const users = require('../src/services/users');

if (!process.env.FIRESTORE_EMULATOR_HOST && !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('Refusing to run: set the emulator env vars or GOOGLE_APPLICATION_CREDENTIALS.');
  process.exit(1);
}

async function main() {
  const filePath = 'C:/Users/asus/.gemini/antigravity/brain/3ecd58c2-0b47-484f-b3b5-771e8e8dacf2/.user_uploaded/media_1791559396161_3f46b111.xlsx';
  const workbook = xlsx.readFile(filePath);
  const sheetName = workbook.SheetNames[0];
  const data = xlsx.utils.sheet_to_json(workbook.Sheets[sheetName]);

  console.log(`Loaded ${data.length} rows from Excel.`);

  // To group by Nbatch
  const batches = {};
  for (const row of data) {
    if (row.Nbatch && !batches[row.Nbatch]) {
      batches[row.Nbatch] = { mentors: {}, students: [] };
    }
  }

  // Create batches
  const batchIdMap = {};
  for (const batchName of Object.keys(batches)) {
    const batchQuery = await db.collection('batches').where('name', '==', batchName).get();
    if (batchQuery.empty) {
      console.log(`Creating batch ${batchName}...`);
      const batchRef = db.collection('batches').doc();
      await batchRef.set({
        name: batchName,
        academicYear: '2026-27',
        isActive: true,
        startDate: Timestamp.now(),
        endDate: Timestamp.fromDate(new Date(Date.now() + 150 * 86400000)),
        createdAt: Timestamp.now(),
      });
      batchIdMap[batchName] = batchRef.id;
    } else {
      batchIdMap[batchName] = batchQuery.docs[0].id;
    }
  }

  console.log('Batch IDs:', batchIdMap);

  // Group users
  for (const row of data) {
    const batchName = row.Nbatch;
    const b = batches[batchName];

    if (row['Mentor Roll No']) {
      const mentorCode = row['Mentor Roll No'].toString().trim();
      if (!b.mentors[mentorCode]) {
        b.mentors[mentorCode] = {
          code: mentorCode,
          name: row['Mentor Name'] || `Mentor ${mentorCode}`,
        };
      }
    }

    if (row['Roll No']) {
      b.students.push({
        roll: row['Roll No'].toString().trim(),
        name: row['Student Name'] || `Student ${row['Roll No']}`,
        mentorCode: row['Mentor Roll No'] ? row['Mentor Roll No'].toString().trim() : null,
        leetcode: row['LeetCode'] || null,
        codeforce: row['Codeforce'] || null,
        hackerrank: row['Hackerrank'] || null,
        linkedin: row['Linkedin'] || null,
        github: row['Github'] || null,
        resume: row['Resume'] || null,
      });
    }
  }

  // Create mentors and students
  for (const batchName of Object.keys(batches)) {
    const b = batches[batchName];
    const batchId = batchIdMap[batchName];

    // Create Mentors
    const mentorUids = {};
    for (const mentorCode of Object.keys(b.mentors)) {
      const m = b.mentors[mentorCode];
      try {
        const { uid } = await users.createMentor({
          mentorCode: m.code,
          name: m.name,
          email: `${m.code.toLowerCase()}@mentorhub.dev`,
          batchId: batchId
        }, { password: 'Mentor@12345' });
        mentorUids[m.code] = uid;
        console.log(`Created mentor ${m.code}`);
      } catch (e) {
        if (e.code === 'already-exists') {
          console.log(`Mentor ${m.code} already exists, fetching uid...`);
          const mentorSnap = await db.collection('mentors').where('mentorCode', '==', m.code).where('batchId', '==', batchId).get();
          if (!mentorSnap.empty) mentorUids[m.code] = mentorSnap.docs[0].id;
        } else {
          console.error(`Failed to create mentor ${m.code}`, e);
        }
      }
    }

    // Create Students
    for (const s of b.students) {
      try {
        const mentorUid = s.mentorCode ? mentorUids[s.mentorCode] : null;
        await users.createStudent({
          studentCode: s.roll,
          name: s.name,
          email: `${s.roll.toLowerCase()}@mentorhub.dev`,
          batchId: batchId,
          mentorId: mentorUid,
          leetcode: s.leetcode,
          codeforce: s.codeforce,
          hackerrank: s.hackerrank,
          linkedin: s.linkedin,
          github: s.github,
          resume: s.resume
        }, { password: 'Student@12345' });
        console.log(`Created student ${s.roll}`);
      } catch (e) {
        if (e.code === 'already-exists') {
          console.log(`Student ${s.roll} already exists.`);
        } else {
          console.error(`Failed to create student ${s.roll}`, e.message);
        }
      }
    }
  }

  console.log('Import completed!');
}

main().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });
