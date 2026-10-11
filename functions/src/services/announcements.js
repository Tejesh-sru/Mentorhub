const { db, FieldValue } = require('../init');
const { AppError } = require('../errors');
const { audienceKeys } = require('../audience');
const { notifyUsers } = require('../notify');

async function recipientIds({ targetType, batchId, mentorId }) {
  const byBatch = (col) => (batchId ? col.where('batchId', '==', batchId) : col);
  if (targetType === 'MENTOR_STUDENTS') {
    return (await db.collection('students').where('mentorId', '==', mentorId).select().get()).docs.map((d) => d.id);
  }
  const ids = [];
  if (targetType === 'ALL' || targetType === 'MENTORS') ids.push(...(await byBatch(db.collection('mentors')).select().get()).docs.map((d) => d.id));
  if (targetType === 'ALL' || targetType === 'STUDENTS') ids.push(...(await byBatch(db.collection('students')).select().get()).docs.map((d) => d.id));
  return ids;
}

async function createAnnouncement(actor, input) {
  let data = { ...input };
  if (actor.role === 'MENTOR') {
    // Mentors can only message their own mentees; target is forced server-side.
    const m = (await db.doc(`mentors/${actor.uid}`).get()).data();
    data = { ...input, targetType: 'MENTOR_STUDENTS', mentorId: actor.uid, batchId: m.batchId };
  } else if (data.targetType === 'MENTOR_STUDENTS') {
    if (!data.mentorId) throw new AppError('invalid-argument', 'Select a mentor for this announcement');
    const m = await db.doc(`mentors/${data.mentorId}`).get();
    if (!m.exists) throw new AppError('not-found', 'Mentor not found');
    data.batchId = m.data().batchId;
  } else {
    data.mentorId = undefined;
  }

  const ref = db.collection('announcements').doc();
  await ref.set({
    title: data.title, message: data.message, targetType: data.targetType,
    batchId: data.batchId || null, mentorId: data.mentorId || null,
    audienceKeys: audienceKeys(data), createdBy: actor.uid,
    createdByName: actor.role === 'ADMIN' ? 'Administrator' : (await db.doc(`mentors/${actor.uid}`).get()).data().name,
    createdByRole: actor.role, createdAt: FieldValue.serverTimestamp(),
  });
  const recipients = (await recipientIds(data)).filter((id) => id !== actor.uid);
  await notifyUsers(recipients, { title: `Announcement: ${data.title}`, message: data.message.slice(0, 200), type: 'ANNOUNCEMENT' });
  return { announcementId: ref.id, recipientCount: recipients.length };
}

module.exports = { createAnnouncement };
