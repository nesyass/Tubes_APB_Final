import 'dart:math';

class AppDateTime {
  static const Duration wibOffset = Duration(hours: 7);
  static const List<String> _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static DateTime nowWib() => DateTime.now().toUtc().add(wibOffset);

  static String nowWibIsoString() => toWibIsoString(nowWib());

  static String toWibIsoString(DateTime wibDateTime) {
    return '${_four(wibDateTime.year)}-${_two(wibDateTime.month)}-${_two(wibDateTime.day)}'
        'T${_two(wibDateTime.hour)}:${_two(wibDateTime.minute)}:${_two(wibDateTime.second)}+07:00';
  }

  static DateTime? parseToWib(String value) {
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) return null;

    final hasExplicitZone =
        RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false)
            .hasMatch(value.trim());
    if (hasExplicitZone || parsed.isUtc) {
      return parsed.toUtc().add(wibOffset);
    }
    return parsed;
  }

  static String normalizeIsoString(dynamic value) {
    if (value == null) return nowWibIsoString();
    if (value is String) {
      final parsed = parseToWib(value);
      return parsed == null ? value : toWibIsoString(parsed);
    }

    try {
      final dynamic timestamp = value;
      final DateTime date = timestamp.toDate();
      return toWibIsoString(date.toUtc().add(wibOffset));
    } catch (_) {
      return value.toString();
    }
  }

  static String formatWib(String value) {
    final parsed = parseToWib(value);
    if (parsed == null) return value;
    return '${parsed.day} ${_monthNames[parsed.month - 1]} ${parsed.year}, '
        '${_two(parsed.hour)}.${_two(parsed.minute)} WIB';
  }

  static String formatShortWib(String value) {
    final parsed = parseToWib(value);
    if (parsed == null) return value;
    return '${parsed.day}/${parsed.month}/${parsed.year} '
        '${_two(parsed.hour)}.${_two(parsed.minute)} WIB';
  }

  static String formatRelativeWib(String value) {
    final parsed = parseToWib(value);
    if (parsed == null) return value;

    final diff = nowWib().difference(parsed);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return formatShortWib(value);
  }

  static String generateOrderId() {
    final now = nowWib();
    final random = Random.secure()
        .nextInt(0x10000)
        .toRadixString(16)
        .padLeft(4, '0')
        .toUpperCase();
    return 'ORD-${_four(now.year)}${_two(now.month)}${_two(now.day)}-'
        '${_two(now.hour)}${_two(now.minute)}${_two(now.second)}-$random';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
  static String _four(int value) => value.toString().padLeft(4, '0');
}

class BranchOperationalMode {
  static const String automatic = 'auto';
  static const String manualOpen = 'manual_open';
  static const String manualClosed = 'manual_closed';

  static const List<String> values = [
    automatic,
    manualOpen,
    manualClosed,
  ];

  static String normalize(dynamic value) {
    final raw = value?.toString();
    if (raw == manualOpen || raw == manualClosed || raw == automatic) {
      return raw!;
    }
    return automatic;
  }

  static String label(String mode) {
    switch (mode) {
      case manualOpen:
        return 'Buka manual';
      case manualClosed:
        return 'Tutup manual';
      default:
        return 'Otomatis';
    }
  }
}

class BranchHoursRange {
  final int openMinutes;
  final int closeMinutes;

  const BranchHoursRange({
    required this.openMinutes,
    required this.closeMinutes,
  });

  bool isOpenAt(DateTime time) {
    final current = time.hour * 60 + time.minute;
    if (openMinutes == closeMinutes) return true;
    if (openMinutes < closeMinutes) {
      return current >= openMinutes && current < closeMinutes;
    }
    return current >= openMinutes || current < closeMinutes;
  }

  String get normalizedLabel =>
      '${_formatMinutes(openMinutes)} - ${_formatMinutes(closeMinutes)}';

  static String _formatMinutes(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return '${hour.toString().padLeft(2, '0')}.${minute.toString().padLeft(2, '0')}';
  }
}

class BranchSchedule {
  static BranchHoursRange? parse(String value) {
    final matches =
        RegExp(r'(\d{1,2})(?:\s*[:.]\s*(\d{2}))?').allMatches(value).toList();
    if (matches.length < 2) return null;

    final openMinutes = _timeMatchToMinutes(matches[0]);
    final closeMinutes = _timeMatchToMinutes(matches[1]);
    if (openMinutes == null || closeMinutes == null) return null;

    return BranchHoursRange(
      openMinutes: openMinutes,
      closeMinutes: closeMinutes,
    );
  }

  static String normalizeOpenHours(String value) {
    final parsed = parse(value);
    return parsed?.normalizedLabel ?? value.trim();
  }

  static bool isOpenBySchedule(String openHours, {DateTime? now}) {
    final parsed = parse(openHours);
    if (parsed == null) return false;
    return parsed.isOpenAt(now ?? AppDateTime.nowWib());
  }

  static bool effectiveIsOpen({
    required String openHours,
    required String operationalMode,
    required bool fallbackIsOpen,
  }) {
    switch (BranchOperationalMode.normalize(operationalMode)) {
      case BranchOperationalMode.manualOpen:
        return true;
      case BranchOperationalMode.manualClosed:
        return false;
      default:
        final parsed = parse(openHours);
        if (parsed == null) return fallbackIsOpen;
        return parsed.isOpenAt(AppDateTime.nowWib());
    }
  }

  static int? _timeMatchToMinutes(RegExpMatch match) {
    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '0');
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }
}
