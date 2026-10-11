import 'package:intl/intl.dart';

String fmtDate(DateTime? d) => d == null ? '—' : DateFormat('dd MMM yyyy').format(d.toLocal());
String fmtDateTime(DateTime? d) => d == null ? '—' : DateFormat('dd MMM yyyy, hh:mm a').format(d.toLocal());

class Format {
  static String date(DateTime? d) => fmtDate(d);
  static String dateTime(DateTime? d) => fmtDateTime(d);
}

String timeUntil(DateTime d) {
  final diff = d.difference(DateTime.now());
  final abs = diff.abs();
  final text = abs.inDays > 0
      ? '${abs.inDays}d ${abs.inHours % 24}h'
      : '${abs.inHours}h ${abs.inMinutes % 60}m';
  return diff.isNegative ? '$text ago' : 'in $text';
}

String labelOf(String s) {
  final t = s.toLowerCase().replaceAll('_', ' ');
  return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
}
