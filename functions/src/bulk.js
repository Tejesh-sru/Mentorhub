const { db } = require('./init');
const { AppError } = require('./errors');

// Runs many writes through a BulkWriter (auto-batched, retried). Not atomic: if some writes fail we throw
// after the rest are flushed; `recomputeStats` can repair the denormalised counters.
async function runBulk(fn) {
  const writer = db.bulkWriter();
  const errors = [];
  const track = (p) => p.catch((e) => { errors.push(e); });
  await fn({
    create: (ref, data) => track(writer.create(ref, data)),
    set: (ref, data, opts) => track(writer.set(ref, data, opts)),
    update: (ref, data) => track(writer.update(ref, data)),
    delete: (ref) => track(writer.delete(ref)),
  });
  await writer.close();
  if (errors.length) {
    console.error('Bulk write failures', errors.slice(0, 3));
    throw new AppError('internal', `${errors.length} write(s) failed. Please retry.`);
  }
}
module.exports = { runBulk };
