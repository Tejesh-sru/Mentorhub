const { FieldValue } = require('firebase-admin/firestore');
const { STATUSES } = require('./constants');

// students/{uid}.stats = { ASSIGNED: n, IN_PROGRESS: n, ... } is a denormalised counter map kept in sync by the
// functions. Progress % is NEVER stored: it is always derived with buildProgress().
const emptyStats = () => Object.fromEntries(STATUSES.map((s) => [s, 0]));

// Update payload (dotted paths) moving one assignment from status `from` to status `to` (either may be null).
const statsMove = (from, to) => {
  if (from === to) return {};
  const u = {};
  if (from) u[`stats.${from}`] = FieldValue.increment(-1);
  if (to) u[`stats.${to}`] = FieldValue.increment(1);
  return u;
};

const buildProgress = (stats = {}) => {
  const c = { ...emptyStats(), ...stats };
  const assigned = STATUSES.reduce((sum, s) => sum + (c[s] || 0), 0);
  const completed = c.APPROVED;
  return {
    assigned,
    completed,
    overdue: c.OVERDUE,
    pending: assigned - completed - c.OVERDUE,
    awaitingReview: c.SUBMITTED,
    percentage: assigned ? Math.round((completed / assigned) * 1000) / 10 : 0,
  };
};

module.exports = { emptyStats, statsMove, buildProgress };
