// code = an HttpsError code: invalid-argument | not-found | already-exists | permission-denied | failed-precondition | internal
class AppError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
    this.isAppError = true;
  }
}
module.exports = { AppError };
