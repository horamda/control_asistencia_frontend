class DateFormatter {
  static String formatDisplayDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString().padLeft(4, '0');
    return '$d/$m/$y';
  }

  static String formatDisplayDateShort(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m';
  }

  static String formatApiDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static DateTime? parseFlexibleDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }

    final slashMatch = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(value);
    if (slashMatch != null) {
      final day = int.tryParse(slashMatch.group(1)!);
      final month = int.tryParse(slashMatch.group(2)!);
      final year = int.tryParse(slashMatch.group(3)!);
      return _buildSafeDate(year: year, month: month, day: day);
    }

    final isoMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (isoMatch != null) {
      final year = int.tryParse(isoMatch.group(1)!);
      final month = int.tryParse(isoMatch.group(2)!);
      final day = int.tryParse(isoMatch.group(3)!);
      return _buildSafeDate(year: year, month: month, day: day);
    }

    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return null;
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static String? toApiDateOrNull(String raw) {
    final parsed = parseFlexibleDate(raw);
    if (parsed == null) {
      return null;
    }
    return formatApiDate(parsed);
  }

  static String formatApiDateForDisplay(String? raw, {String fallback = '-'}) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return fallback;
    }
    final parsed = parseFlexibleDate(value);
    if (parsed == null) {
      return value;
    }
    return formatDisplayDate(parsed);
  }

  static String formatApiDateForDisplayShort(
    String? raw, {
    String fallback = '-',
  }) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return fallback;
    }
    final parsed = parseFlexibleDate(value);
    if (parsed == null) {
      return value;
    }
    return formatDisplayDateShort(parsed);
  }

  static DateTime? _buildSafeDate({
    required int? year,
    required int? month,
    required int? day,
  }) {
    if (year == null || month == null || day == null) {
      return null;
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    final built = DateTime(year, month, day);
    if (built.year != year || built.month != month || built.day != day) {
      return null;
    }
    return built;
  }
}
