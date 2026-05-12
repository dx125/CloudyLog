import 'package:intl/intl.dart';

class CloudingEntry {
  const CloudingEntry({required this.date, required this.count});

  final DateTime date;
  final int count;

  static String dateKey(DateTime date) =>
      DateFormat('yyyy-MM-dd').format(DateTime(date.year, date.month, date.day));

  CloudingEntry copyWith({int? count}) =>
      CloudingEntry(date: date, count: count ?? this.count);
}
