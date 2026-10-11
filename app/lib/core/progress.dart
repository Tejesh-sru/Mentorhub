const List<String> kStatuses = ['ASSIGNED', 'IN_PROGRESS', 'SUBMITTED', 'APPROVED', 'NEEDS_CHANGES', 'OVERDUE'];

/// Progress is always DERIVED from the stats counters: approved / assigned * 100 (never stored).
/// Mirrors buildProgress() in functions/src/stats.js.
class Progress {
  const Progress({
    required this.assigned,
    required this.completed,
    required this.overdue,
    required this.pending,
    required this.awaitingReview,
    required this.percentage,
  });

  final int assigned;
  final int completed;
  final int overdue;
  final int pending;
  final int awaitingReview;
  final double percentage;

  factory Progress.fromStats(Map<String, int> stats) {
    int c(String k) => stats[k] ?? 0;
    final assigned = kStatuses.fold<int>(0, (sum, s) => sum + c(s));
    final completed = c('APPROVED');
    final pct = assigned == 0 ? 0.0 : (completed / assigned * 1000).round() / 10;
    return Progress(
      assigned: assigned,
      completed: completed,
      overdue: c('OVERDUE'),
      pending: assigned - completed - c('OVERDUE'),
      awaitingReview: c('SUBMITTED'),
      percentage: pct,
    );
  }

  /// Average of the percentages of students that have at least one task (mentor average).
  static double average(Iterable<Progress> list) {
    final active = list.where((p) => p.assigned > 0).toList();
    if (active.isEmpty) return 0;
    final sum = active.fold<double>(0, (s, p) => s + p.percentage);
    return (sum / active.length * 10).round() / 10;
  }
}
