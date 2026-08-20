import 'dart:convert';

/// Clinic opening hours in the clinic's own timezone.
///
/// Times are minutes from local midnight (10:00 = 600). [utcOffsetMinutes]
/// is the clinic offset from UTC (India = 330).
class DayHours {
  final int open;
  final int close;
  final int? breakStart;
  final int? breakEnd;

  const DayHours({
    required this.open,
    required this.close,
    this.breakStart,
    this.breakEnd,
  });

  Map<String, dynamic> toJson() => {
        'open': open,
        'close': close,
        if (breakStart != null) 'breakStart': breakStart,
        if (breakEnd != null) 'breakEnd': breakEnd,
      };

  factory DayHours.fromJson(Map<String, dynamic> json) {
    return DayHours(
      open: (json['open'] as num?)?.toInt() ?? 600,
      close: (json['close'] as num?)?.toInt() ?? 1140,
      breakStart: (json['breakStart'] as num?)?.toInt(),
      breakEnd: (json['breakEnd'] as num?)?.toInt(),
    );
  }
}

class ClinicHours {
  static const settingId = 'clinic_hours___';
  static const tokenSettingId = 'n8n_book_token_';

  /// ISO weekday 1=Mon … 7=Sun.
  final Map<int, DayHours?> week;
  final int utcOffsetMinutes;
  final int slotMinutes;
  final String defaultOperatorId;
  final List<String> closedDates;

  const ClinicHours({
    required this.week,
    this.utcOffsetMinutes = 330,
    this.slotMinutes = 15,
    this.defaultOperatorId = '',
    this.closedDates = const [],
  });

  static ClinicHours get indiaDefault {
    const work = DayHours(
      open: 600,
      close: 1140,
      breakStart: 810,
      breakEnd: 870,
    );
    return const ClinicHours(
      utcOffsetMinutes: 330,
      slotMinutes: 15,
      week: {
        1: work,
        2: work,
        3: work,
        4: work,
        5: work,
        6: work,
        7: null,
      },
    );
  }

  factory ClinicHours.fromJsonString(String raw) {
    if (raw.trim().isEmpty) return ClinicHours.indiaDefault;
    try {
      return ClinicHours.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return ClinicHours.indiaDefault;
    }
  }

  factory ClinicHours.fromJson(Map<String, dynamic> json) {
    final week = <int, DayHours?>{};
    final rawWeek = json['week'];
    if (rawWeek is Map) {
      for (var d = 1; d <= 7; d++) {
        final v = rawWeek['$d'] ?? rawWeek[d];
        if (v == null) {
          week[d] = null;
        } else if (v is Map) {
          week[d] = DayHours.fromJson(Map<String, dynamic>.from(v));
        }
      }
    }
    if (week.isEmpty) return ClinicHours.indiaDefault;
    return ClinicHours(
      week: week,
      utcOffsetMinutes: (json['utcOffsetMinutes'] as num?)?.toInt() ?? 330,
      slotMinutes: (json['slotMinutes'] as num?)?.toInt() ?? 15,
      defaultOperatorId: json['defaultOperatorId']?.toString() ?? '',
      closedDates: List<String>.from(json['closedDates'] ?? const []),
    );
  }

  Map<String, dynamic> toJson() => {
        'utcOffsetMinutes': utcOffsetMinutes,
        'slotMinutes': slotMinutes,
        'defaultOperatorId': defaultOperatorId,
        'closedDates': closedDates,
        'week': {
          for (final e in week.entries)
            '${e.key}': e.value?.toJson(),
        },
      };

  String toJsonString() => jsonEncode(toJson());

  bool isClosedDate(DateTime clinicLocalDate) {
    final key =
        '${clinicLocalDate.year.toString().padLeft(4, '0')}-${clinicLocalDate.month.toString().padLeft(2, '0')}-${clinicLocalDate.day.toString().padLeft(2, '0')}';
    return closedDates.contains(key);
  }

  static String formatMinutes(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  static int? parseMinutes(String hhmm) {
    final parts = hhmm.trim().split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }
}

class EvolutionSettings {
  static const settingId = 'evo_settings___';

  final String baseUrl;
  final String apiKey;
  final String instance;
  final String confirmTemplate;
  final String remindTemplate;
  final String clinicName;
  final String googleMapsUrl;
  final String staffGroupJid;
  final String marketing1;
  final String marketing2;
  final String marketing3;
  final String marketing4;
  final String clinicAddress;

  const EvolutionSettings({
    this.baseUrl = '',
    this.apiKey = '',
    this.instance = '',
    this.confirmTemplate =
        'Hi {name}, your appointment at {clinic} is on {date} at {time}. Reply if you need to reschedule.',
    this.remindTemplate =
        'Reminder: {name}, you have an appointment at {clinic} on {date} at {time}.',
    this.clinicName = 'the clinic',
    this.googleMapsUrl = '',
    this.staffGroupJid = '120363426681576301@g.us',
    this.marketing1 = '',
    this.marketing2 = '',
    this.marketing3 = '',
    this.marketing4 = '',
    this.clinicAddress = '',
  });

  factory EvolutionSettings.fromJsonString(String raw) {
    if (raw.trim().isEmpty) return const EvolutionSettings();
    try {
      return EvolutionSettings.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const EvolutionSettings();
    }
  }

  factory EvolutionSettings.fromJson(Map<String, dynamic> json) {
    return EvolutionSettings(
      baseUrl: json['baseUrl']?.toString() ?? '',
      apiKey: json['apiKey']?.toString() ?? '',
      instance: json['instance']?.toString() ?? '',
      confirmTemplate: json['confirmTemplate']?.toString() ??
          const EvolutionSettings().confirmTemplate,
      remindTemplate: json['remindTemplate']?.toString() ??
          const EvolutionSettings().remindTemplate,
      clinicName: json['clinicName']?.toString() ?? 'the clinic',
      googleMapsUrl: json['googleMapsUrl']?.toString() ?? '',
      staffGroupJid: json['staffGroupJid']?.toString() ??
          '120363426681576301@g.us',
      marketing1: json['marketing1']?.toString() ?? '',
      marketing2: json['marketing2']?.toString() ?? '',
      marketing3: json['marketing3']?.toString() ?? '',
      marketing4: json['marketing4']?.toString() ?? '',
      clinicAddress: json['clinicAddress']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'instance': instance,
        'confirmTemplate': confirmTemplate,
        'remindTemplate': remindTemplate,
        'clinicName': clinicName,
        'googleMapsUrl': googleMapsUrl,
        'staffGroupJid': staffGroupJid,
        'marketing1': marketing1,
        'marketing2': marketing2,
        'marketing3': marketing3,
        'marketing4': marketing4,
        'clinicAddress': clinicAddress,
      };

  String toJsonString() => jsonEncode(toJson());

  String fill(
    String template, {
    required String name,
    required DateTime when,
  }) {
    final local = when.toLocal();
    final date =
        '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return template
        .replaceAll('{name}', name)
        .replaceAll('{clinic}', clinicName)
        .replaceAll('{date}', date)
        .replaceAll('{time}', time);
  }
}
