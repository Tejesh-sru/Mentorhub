import 'package:flutter_test/flutter_test.dart';
import 'package:mentorhub/core/progress.dart';

void main() {
  test('progress is approved / assigned', () {
    final p = Progress.fromStats({'ASSIGNED': 3, 'APPROVED': 15, 'OVERDUE': 2});
    expect(p.assigned, 20);
    expect(p.percentage, 75);
    expect(p.pending, 3);
    expect(p.overdue, 2);
  });

  test('empty stats give 0%', () {
    expect(Progress.fromStats({}).percentage, 0);
  });

  test('mentor average ignores students without tasks', () {
    final a = Progress.fromStats({'APPROVED': 1, 'ASSIGNED': 1}); // 50%
    final b = Progress.fromStats({'APPROVED': 2}); // 100%
    final c = Progress.fromStats({}); // no tasks
    expect(Progress.average([a, b, c]), 75);
  });
}
