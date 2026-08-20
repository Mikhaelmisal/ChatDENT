import 'package:chatdent/features/leads/clinic_hours.dart';
import 'package:chatdent/features/leads/slot_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final hours = ClinicHours.indiaDefault;
  final engine = SlotEngine(hours);

  test('10:00 IST on a weekday is 04:30 UTC', () {
    final start = engine.clinicLocalToUtc(2026, 8, 19, 600);
    expect(start.toUtc(), DateTime.utc(2026, 8, 19, 4, 30));
    expect(start.toUtc().weekday, DateTime.wednesday);
  });

  test('Sunday is closed in the India default week', () {
    expect(hours.week[7], isNull);
  });

  test('skips occupied intervals for the same operator', () {
    final now = DateTime.utc(2026, 8, 19, 3, 0); // 08:30 IST
    final busyStart = engine.clinicLocalToUtc(2026, 8, 19, 600);
    final busy = [
      OccupiedInterval(
        start: busyStart,
        end: busyStart.add(const Duration(minutes: 15)),
        operatorId: 'doc1',
      ),
    ];
    final hoursWithDoc = ClinicHours(
      week: hours.week,
      utcOffsetMinutes: 330,
      slotMinutes: 15,
      defaultOperatorId: 'doc1',
    );
    final slots = SlotEngine(hoursWithDoc).getFreeSlots(
      from: now,
      days: 1,
      limit: 5,
      busy: busy,
      now: now,
      operatorId: 'doc1',
    );
    expect(slots, isNotEmpty);
    expect(slots.first.start, isNot(busyStart));
    expect(
      slots.every((s) =>
          s.start.isAtSameMomentAs(busyStart) == false),
      isTrue,
    );
  });

  test('slot id round-trips', () {
    final start = DateTime.utc(2026, 8, 19, 4, 30);
    final id = FreeSlot.makeId('doc1', start);
    final parsed = FreeSlot.parseId(id)!;
    expect(parsed.$1, 'doc1');
    expect(parsed.$2.toUtc(), start);
  });

  test('closed dates are skipped', () {
    final closed = ClinicHours(
      week: hours.week,
      utcOffsetMinutes: 330,
      slotMinutes: 15,
      closedDates: ['2026-08-19'],
    );
    final now = DateTime.utc(2026, 8, 19, 3, 0);
    final slots = SlotEngine(closed).getFreeSlots(
      from: now,
      days: 1,
      limit: 8,
      busy: const [],
      now: now,
    );
    expect(slots, isEmpty);
  });
}
