import 'dart:convert';

/// How a medicine should be taken relative to meals.
enum MealTiming {
  beforeMeal,
  afterMeal,
  withMeal,
  anytime,
}

extension MealTimingX on MealTiming {
  String get storageKey {
    switch (this) {
      case MealTiming.beforeMeal:
        return 'before';
      case MealTiming.afterMeal:
        return 'after';
      case MealTiming.withMeal:
        return 'with';
      case MealTiming.anytime:
        return 'any';
    }
  }

  String get labelEn {
    switch (this) {
      case MealTiming.beforeMeal:
        return 'before meals';
      case MealTiming.afterMeal:
        return 'after meals';
      case MealTiming.withMeal:
        return 'with meals';
      case MealTiming.anytime:
        return 'anytime';
    }
  }

  static MealTiming fromStorage(String? raw) {
    switch ((raw ?? '').toLowerCase().trim()) {
      case 'before':
        return MealTiming.beforeMeal;
      case 'with':
        return MealTiming.withMeal;
      case 'any':
      case 'anytime':
        return MealTiming.anytime;
      case 'after':
      default:
        return MealTiming.afterMeal;
    }
  }
}

/// One prescribed medicine line on an appointment.
class PrescriptionLine {
  final String medicine;
  final String dose;
  final String duration;
  final MealTiming meal;

  const PrescriptionLine({
    required this.medicine,
    required this.dose,
    required this.duration,
    this.meal = MealTiming.afterMeal,
  });

  bool get isValid => medicine.trim().isNotEmpty;

  /// Human-readable line for WhatsApp / print / UI tags.
  String toDisplay() {
    final parts = <String>[
      medicine.trim(),
      if (dose.trim().isNotEmpty) dose.trim(),
      if (duration.trim().isNotEmpty) duration.trim(),
      meal.labelEn,
    ];
    return parts.join(' — ');
  }

  Map<String, dynamic> toJson() => {
        'm': medicine.trim(),
        'd': dose.trim(),
        'u': duration.trim(),
        't': meal.storageKey,
      };

  factory PrescriptionLine.fromJson(Map<String, dynamic> json) {
    return PrescriptionLine(
      medicine: json['m']?.toString() ?? json['medicine']?.toString() ?? '',
      dose: json['d']?.toString() ?? json['dose']?.toString() ?? '',
      duration: json['u']?.toString() ?? json['duration']?.toString() ?? '',
      meal: MealTimingX.fromStorage(
          json['t']?.toString() ?? json['meal']?.toString()),
    );
  }

  /// Encode for appointment.prescriptions storage (JSON object string).
  String toStored() => jsonEncode(toJson());

  /// Parse a stored appointment prescription string (JSON or legacy free text).
  static PrescriptionLine parse(String raw) {
    final t = raw.trim();
    if (t.startsWith('{') && t.endsWith('}')) {
      try {
        final decoded = jsonDecode(t);
        if (decoded is Map) {
          return PrescriptionLine.fromJson(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }
    if (t.contains(' — ')) {
      final parts = t.split(' — ').map((e) => e.trim()).toList();
      return PrescriptionLine(
        medicine: parts.isNotEmpty ? parts[0] : t,
        dose: parts.length > 1 ? parts[1] : '',
        duration: parts.length > 2 ? parts[2] : '',
        meal: parts.length > 3
            ? MealTimingX.fromStorage(_mealFromLabel(parts[3]))
            : MealTiming.afterMeal,
      );
    }
    return PrescriptionLine(
      medicine: t.replaceAll('-', ' '),
      dose: '',
      duration: '',
    );
  }

  static String _mealFromLabel(String label) {
    final l = label.toLowerCase();
    if (l.contains('before')) return 'before';
    if (l.contains('with')) return 'with';
    if (l.contains('any')) return 'any';
    return 'after';
  }

  static List<PrescriptionLine> parseList(List<String> raw) =>
      raw.map(parse).where((e) => e.isValid).toList();

  static String formatWhatsAppNote(List<String> raw) {
    final lines = parseList(raw);
    if (lines.isEmpty) return '';
    final buf = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      buf.writeln('${i + 1}. ${lines[i].toDisplay()}');
    }
    return buf.toString().trim();
  }
}
