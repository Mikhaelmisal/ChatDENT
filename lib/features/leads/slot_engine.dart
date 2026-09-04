import 'package:chatdent/features/appointments/appointment_model.dart';
import 'package:chatdent/features/leads/clinic_hours.dart';

class FreeSlot {
  final String id;
  final DateTime start;
  final DateTime end;
  final String operatorId;

  const FreeSlot({
    required this.id,
    required this.start,
    required this.end,
    required this.operatorId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        'operatorId': operatorId,
      };

  static String makeId(String operatorId, DateTime start) {
    return '$operatorId|${start.toUtc().millisecondsSinceEpoch}';
  }

  static (String, DateTime)? parseId(String id) {
    final i = id.indexOf('|');
    if (i < 1) return null;
    final op = id.substring(0, i);
    final ms = int.tryParse(id.substring(i + 1));
    if (ms == null) return null;
    return (op, DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true));
  }
}

class OccupiedInterval {
  final DateTime start;
  final DateTime end;
  final String operatorId;

  const OccupiedInterval({
    required this.start,
    required this.end,
    required this.operatorId,
  });

  factory OccupiedInterval.fromAppointment(Appointment a) {
    return OccupiedInterval(
      start: a.date,
      end: a.endDate,
      operatorId: a.operatorsIDs.isEmpty ? '' : a.operatorsIDs.first,
    );
  }
}

class SlotEngine {
  final ClinicHours hours;

  const SlotEngine(this.hours);

  /// Clinic-local calendar date for an instant.
  DateTime clinicLocalDate(DateTime instant) {
    return instant.toUtc().add(Duration(minutes: hours.utcOffsetMinutes));
  }

  DateTime clinicLocalToUtc(int year, int month, int day, int minutes) {
    final midnightUtc = DateTime.utc(year, month, day)
        .subtract(Duration(minutes: hours.utcOffsetMinutes));
    return midnightUtc.add(Duration(minutes: minutes));
  }

  bool overlaps(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) {
    return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
  }

  bool isFree({
    required DateTime start,
    required DateTime end,
    required String operatorId,
    required List<OccupiedInterval> busy,
  }) {
    for (final b in busy) {
      final sameChair = b.operatorId.isEmpty ||
          operatorId.isEmpty ||
          b.operatorId == operatorId;
      if (!sameChair) continue;
      if (overlaps(start, end, b.start, b.end)) return false;
    }
    return true;
  }

  List<FreeSlot> getFreeSlots({
    required DateTime from,
    int days = 7,
    int? durationMinutes,
    String? operatorId,
    int limit = 12,
    required List<OccupiedInterval> busy,
    DateTime? now,
  }) {
    final duration = durationMinutes ?? hours.slotMinutes;
    final op = (operatorId == null || operatorId.isEmpty)
        ? hours.defaultOperatorId
        : operatorId;
    final clock = now ?? DateTime.now().toUtc();
    final startLocal = clinicLocalDate(from.toUtc());
    var day = DateTime.utc(startLocal.year, startLocal.month, startLocal.day);
    final slots = <FreeSlot>[];

    for (var d = 0; d < days && slots.length < limit; d++) {
      final localDay = day.add(Duration(days: d));
      if (hours.isClosedDate(localDay)) continue;
      final weekday = localDay.weekday; // 1-7
      final dayHours = hours.week[weekday];
      if (dayHours == null) continue;

      var cursor = dayHours.open;
      while (cursor + duration <= dayHours.close && slots.length < limit) {
        final inBreak = dayHours.breakStart != null &&
            dayHours.breakEnd != null &&
            cursor < dayHours.breakEnd! &&
            cursor + duration > dayHours.breakStart!;
        if (inBreak) {
          cursor = dayHours.breakEnd!;
          continue;
        }
        final start = clinicLocalToUtc(
            localDay.year, localDay.month, localDay.day, cursor);
        final end = start.add(Duration(minutes: duration));
        if (!start.isAfter(clock)) {
          cursor += duration;
          continue;
        }
        if (isFree(start: start, end: end, operatorId: op, busy: busy)) {
          slots.add(FreeSlot(
            id: FreeSlot.makeId(op, start),
            start: start,
            end: end,
            operatorId: op,
          ));
        }
        cursor += duration;
      }
    }
    return slots;
  }
}
