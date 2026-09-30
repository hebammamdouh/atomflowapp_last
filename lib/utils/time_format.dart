// utils/time_format.dart
// تحويل ISO timestamp لصيغة قابلة للقراءة زي "2h 15m ago"

String formatTimeAgo(String? isoString) {
  if (isoString == null) return '--';
  final date = DateTime.tryParse(isoString);
  if (date == null) return '--';

  final diff = DateTime.now().toUtc().difference(date.toUtc());
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
  return '${diff.inDays}d ${diff.inHours % 24}h ago';
}

const List<String> _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const List<String> _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _twoDigits(int n) => n.toString().padLeft(2, '0');

// تنسيق التاريخ والوقت الحاليين لعرضهم في بداية شاشة الـ Home
// مثال: "Tuesday, 11 Aug 2026  •  14:35"
String formatFullDateTime(DateTime dt) {
  final weekday = _weekdayNames[dt.weekday - 1];
  final month = _monthNames[dt.month - 1];
  final time = '${_twoDigits(dt.hour)}:${_twoDigits(dt.minute)}';
  return '$weekday, ${dt.day} $month ${dt.year}  •  $time';
}

// تنسيق مختصر لصف واحد في سجل القرايات (Reports) - فيه الثواني كمان عشان الدقة
// مثال: "11 Aug 2026, 14:35:02"
String formatLogTimestamp(DateTime? dt) {
  if (dt == null) return '--';
  final local = dt.toLocal();
  final month = _monthNames[local.month - 1];
  final time =
      '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}:${_twoDigits(local.second)}';
  return '${local.day} $month ${local.year}, $time';
}

// تنسيق مختصر لاسم اليوم (3 حروف) - يستخدم في تسميات محاور الترند الأسبوعي
String formatShortWeekday(DateTime dt) {
  const short = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return short[dt.weekday - 1];
}

String formatDuration(String? isoString) {
  if (isoString == null) return '--';
  final date = DateTime.tryParse(isoString);
  if (date == null) return '--';

  final diff = DateTime.now().toUtc().difference(date.toUtc());
  if (diff.inSeconds < 60) return 'a few seconds';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 24) return '${diff.inHours}h ${diff.inMinutes % 60}m';
  return '${diff.inDays}d ${diff.inHours % 24}h';
}
