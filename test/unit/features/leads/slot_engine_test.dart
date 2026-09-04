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
        end: busyStart.add(const Duration(minutes: 20)),
        operatorId: 'doc1',
      ),
    ];
    final hoursWithDoc = ClinicHours(
      week: hours.week,
      utcOffsetMinutes: 330,
      slotMinutes: 20,
      defaultOperatorId: 'doc1',
    );
    final slots = SlotEngine(hoursWithDoc).getFreeSlots(
      from: now,
      days: 1,
      durationMinutes: 20,
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
      slotMinutes: 20,
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

  test('skips the gap between morning close and evening open', () {
    final now = DateTime.utc(2026, 8, 19, 3, 0);
    final sample = hours.week[3]!;
    final slots = engine.getFreeSlots(
      from: now,
      days: 1,
      durationMinutes: 20,
      limit: 40,
      busy: const [],
      now: now,
    );
    expect(slots, isNotEmpty);
    expect(sample.hasEvening, isTrue);
    for (final slot in slots) {
      final wall = engine.clinicLocalDate(slot.start);
      final mins = wall.hour * 60 + wall.minute;
      expect(
        mins + 20 <= sample.morningClose || mins >= sample.eveningOpen!,
        isTrue,
        reason: 'slot at $mins is inside the closed gap',
      );
    }
  });

  test('three twenty-minute slots fit in one hour', () {
    const hour = DayHours(open: 600, close: 660);
    final tight = ClinicHours(
      week: {for (var d = 1; d <= 6; d++) d: hour, 7: null},
      utcOffsetMinutes: 330,
      slotMinutes: 20,
    );
    final now = DateTime.utc(2026, 8, 19, 3, 0);
    final slots = SlotEngine(tight).getFreeSlots(
      from: now,
      days: 1,
      durationMinutes: 20,
      limit: 8,
      busy: const [],
      now: now,
    );
    expect(slots.length, 3);
    expect(slots[1].start.difference(slots[0].start).inMinutes, 20);
    expect(slots[2].start.difference(slots[1].start).inMinutes, 20);
  });

  test('weekday slots include 1:00, 1:20, 1:40 when slot length is 20', () {
    final starts = hours.slotStartsForWeekday(3);
    expect(starts, containsAll([780, 800, 820]));
    expect(starts, isNot(contains(840)));
    expect(starts.where((m) => m >= 840 && m < 1020), isEmpty);
  });

  test('morning-only day has no evening slots', () {
    final morning = ClinicHours(
      week: {
        for (var d = 1; d <= 6; d++)
          d: DayHours.sessions(morningOpen: 600, morningClose: 840),
        7: null,
      },
      utcOffsetMinutes: 330,
      slotMinutes: 20,
    );
    final starts = morning.slotStartsForWeekday(1);
    expect(starts.first, 600);
    expect(starts.last, 820);
    expect(starts.any((m) => m >= 1020), isFalse);
  });

  test('snapToSlot uses first slot at midnight and next slot after the clock', () {
    final wed = DateTime(2026, 8, 19);
    expect(hours.snapToSlot(wed).hour, 10);
    expect(hours.snapToSlot(wed).minute, 0);
    final aroundOne = DateTime(2026, 8, 19, 13, 7);
    expect(hours.snapToSlot(aroundOne).hour, 13);
    expect(hours.snapToSlot(aroundOne).minute, 20);
  });
}
