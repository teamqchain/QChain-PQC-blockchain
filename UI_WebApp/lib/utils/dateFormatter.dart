class DateFormatter {
  static const List<String> _months = [
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

  static String getMonthName(int month) {
    if (month < 1 || month > 12) return '';
    return _months[month - 1];
  }

  /// Formats a DateTime into a 12-hour string (e.g., "10:00 AM")
  static String format12h(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$displayH:${m.toString().padLeft(2, '0')} $period';
  }

  /// Parses an ISO string and returns ONLY the date (e.g., "15 Jan 2025")
  static String formatIsoDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')} ${getMonthName(dt.month)} ${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  /// Parses an ISO string and returns BOTH date and time (e.g., "15 Jan 2025, 10:00 AM")
  static String formatIsoDateAndTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final datePart =
          '${dt.day.toString().padLeft(2, '0')} ${getMonthName(dt.month)} ${dt.year}';
      final timePart = format12h(dt);

      return '$datePart, $timePart'; // Combines them into one string
    } catch (_) {
      return iso;
    }
  }

  // ── Helper to convert "15 Jan 2025 14:32" to "15 Jan 2025 2:32 PM" ──
  static String formatDateTime(String raw) {
    if (raw.isEmpty) return raw;

    final parts = raw.trim().split(' ');
    // Ensure we have at least date, month, year, and time
    if (parts.length < 4) return raw;

    final timePart = parts.last; // e.g., "14:32"
    final timeParts = timePart.split(':');

    if (timeParts.length != 2) return raw;

    final h = int.tryParse(timeParts[0]);
    final m = timeParts[1];

    if (h == null) return raw;

    // Apply the 12-hour logic
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h > 12 ? h - 12 : (h == 0 ? 12 : h);

    // Rebuild the string without the original 24h time, then append the 12h time
    final datePart = parts.sublist(0, parts.length - 1).join(' ');
    return '$datePart $displayH:$m $period';
  }

}
