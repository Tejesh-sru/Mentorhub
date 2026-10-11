const { initializeApp, getApps } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');

if (!getApps().length) initializeApp();
const db = getFirestore();
db.settings({ ignoreUndefinedProperties: true });

module.exports = { db, auth: getAuth(), FieldValue, Timestamp };
