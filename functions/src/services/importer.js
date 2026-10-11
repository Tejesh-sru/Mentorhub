const { db } = require('../init');
const { mentorRow, studentRow } = require('../validators');
const { createMentor, createStudent } = require('./users');
const { notifyAdmins } = require('../notify');

const normalise = (row) => Object.fromEntries(Object.entries(row).map(([k, v]) => [
  String(k).trim().toLowerCase().replace(/\s+/g, '_'), typeof v === 'string' ? v.trim() : v == null ? '' : String(v),
]));

// Imports one chunk (<=100 rows) parsed by the Flutter app. The client loops over chunks and merges results.
// Uniqueness (IDs per batch, emails) is enforced by createMentor/createStudent, so duplicates inside the file
// and against existing data are both reported per row. New users get the server's DEFAULT_USER_PASSWORD.
async function importRows({ kind, rows, startRow = 2 }) {
  const batches = new Map((await db.collection('batches').get()).docs.map((d) => [String(d.data().name).toLowerCase(), d.id]));
  const mentorByKey = new Map();
  if (kind === 'students') {
    (await db.collection('mentors').get()).docs.forEach((d) => mentorByKey.set(`${d.data().batchId}:${String(d.data().mentorCode).toLowerCase()}`, d.id));
  }

  const errors = [];
  let successful = 0;
  const schema = kind === 'mentors' ? mentorRow : studentRow;

  const work = rows.map((raw, i) => async () => {
    const rowNo = startRow + i;
    const clean = normalise(raw);
    const id = clean.mentor_id && kind === 'mentors' ? clean.mentor_id : clean.student_id || '';
    const fail = (message) => errors.push({ row: rowNo, id, message });
    const parsed = schema.safeParse({ ...clean, phone: clean.phone || undefined });
    if (!parsed.success) return fail(parsed.error.issues.map((x) => x.message).join('; '));
    const r = parsed.data;
    const batchId = batches.get(r.batch.toLowerCase());
    if (!batchId) return fail(`Batch "${r.batch}" does not exist`);
    try {
      if (kind === 'mentors') {
        await createMentor({ mentorCode: r.mentor_id, name: r.name, phone: r.phone, email: r.email, batchId });
      } else {
        const mentorId = mentorByKey.get(`${batchId}:${r.mentor_id.toLowerCase()}`);
        if (!mentorId) return fail(`Invalid mentor_id "${r.mentor_id}" for this batch`);
        await createStudent({ studentCode: r.student_id, name: r.name, phone: r.phone, email: r.email, batchId, mentorId });
      }
      successful += 1;
    } catch (e) {
      fail(e.isAppError ? e.message : 'Could not save this row');
    }
  });

  // small worker pool (5 concurrent) keeps a 100-row chunk well inside the function timeout
  const queue = [...work];
  await Promise.all(Array.from({ length: 5 }, async () => { while (queue.length) await queue.shift()(); }));

  errors.sort((a, b) => a.row - b.row);
  await notifyAdmins({
    title: `${kind === 'mentors' ? 'Mentor' : 'Student'} import chunk finished`,
    message: `${rows.length} rows processed: ${successful} successful, ${errors.length} failed.`,
    type: 'SYSTEM',
  });
  return { processed: rows.length, successful, failed: errors.length, errors };
}

module.exports = { importRows };
