// Announcements store `audienceKeys` so clients can query with array-contains-any and rules can verify access.
// Must stay in sync with mentorKeys()/studentKeys() in firestore.rules and the Flutter app.
const audienceKeys = ({ targetType, batchId, mentorId }) => {
  const b = batchId || '*';
  switch (targetType) {
    case 'ALL': return [`all:${b}`];
    case 'MENTORS': return [`mentors:${b}`];
    case 'STUDENTS': return [`students:${b}`];
    case 'MENTOR_STUDENTS': return [`mentor:${mentorId}`];
    default: return [];
  }
};
module.exports = { audienceKeys };
