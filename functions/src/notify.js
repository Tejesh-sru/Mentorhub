const { db, FieldValue } = require('./init');
const { runBulk } = require('./bulk');

const notificationData = (userId, { title, message, type = 'SYSTEM' }) => ({
  userId, title, message, type, isRead: false, createdAt: FieldValue.serverTimestamp(),
});

// Same message to many users.
async function notifyUsers(userIds, payload) {
  const unique = [...new Set(userIds.filter(Boolean))];
  if (!unique.length) return 0;
  await runBulk((w) => { unique.forEach((id) => w.create(db.collection('notifications').doc(), notificationData(id, payload))); });
  return unique.length;
}

// Different message per user: items = [{ userId, title, message, type }]
async function notifyEach(items) {
  if (!items.length) return 0;
  await runBulk((w) => { items.forEach((i) => w.create(db.collection('notifications').doc(), notificationData(i.userId, i))); });
  return items.length;
}

async function notifyAdmins(payload) {
  const snap = await db.collection('users').where('role', '==', 'ADMIN').get();
  return notifyUsers(snap.docs.map((d) => d.id), payload);
}

module.exports = { notificationData, notifyUsers, notifyEach, notifyAdmins };
