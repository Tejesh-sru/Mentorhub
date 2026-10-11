const chunk = (arr, size) => {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
};

const defaultPassword = () => {
  const { AppError } = require('./errors');
  const pw = process.env.DEFAULT_USER_PASSWORD;
  if (!pw || pw.length < 8) throw new AppError('failed-precondition', 'DEFAULT_USER_PASSWORD is not configured on the server');
  return pw;
};

const formatDate = (date) =>
  new Intl.DateTimeFormat('en-IN', { dateStyle: 'medium', timeZone: 'Asia/Kolkata' }).format(date);

module.exports = { chunk, defaultPassword, formatDate };
