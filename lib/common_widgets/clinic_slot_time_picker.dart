import 'package:chatdent/features/leads/clinic_hours.dart';
import 'package:chatdent/features/settings/services_settings/responsive_row.dart';
import 'package:chatdent/features/settings/settings_stores.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';

/// Hour + slot-minute pickers aligned to clinic open/close and slot length.
class ClinicSlotTimePicker extends StatelessWidget {
  final DateTime value;
  final void Function(DateTime) onChange;
  final Key? hourKey;

  /// When set, only these minutes-from-midnight are offered (free slots).
  final List<int>? allowedStarts;

  const ClinicSlotTimePicker({
    super.key,
    required this.value,
    required this.onChange,
    this.hourKey,
    this.allowedStarts,
  });

  ClinicHours get _hours => ClinicHours.fromJsonString(
      globalSettings.get(ClinicHours.settingId).value);

  @override
  Widget build(BuildContext context) {
    final hours = _hours;
    var slots = [...hours.slotStartsForLocalDate(value)];
    if (allowedStarts != null) {
      final allow = allowedStarts!.toSet();
      slots = [for (final s in slots) if (allow.contains(s)) s];
    }
    final current = value.hour * 60 + value.minute;
    if (slots.isEmpty) {
      return InfoBar(
        title: Txt(txt(allowedStarts != null ? 'noFreeSlots' : 'closed')),
        severity: InfoBarSeverity.warning,
        isLong: true,
      );
    }

    if (!slots.contains(current) && allowedStarts == null) {
      slots.add(current);
      slots.sort();
    }

    final display = slots.contains(current) ? current : slots.first;
    final hoursOfDay = [
      for (final s in slots) s ~/ 60,
    ].toSet().toList()
      ..sort();
    final hour = display ~/ 60;
    final selectedHour = hoursOfDay.contains(hour) ? hour : hoursOfDay.first;
    final minutesThisHour = [
      for (final s in slots)
        if (s ~/ 60 == selectedHour) s % 60,
    ];
    final selectedMinute = display % 60;
    final minuteValue = minutesThisHour.contains(selectedMinute)
        ? selectedMinute
        : minutesThisHour.first;

    return ResponsiveRow(children: [
      ComboBox<int>(
        key: hourKey,
        isExpanded: true,
        value: selectedHour,
        items: [
          for (final h in hoursOfDay)
            ComboBoxItem<int>(
              value: h,
              child: Text(ClinicHours.formatHour(h)),
            ),
        ],
        onChanged: (h) {
          if (h == null) return;
          final opts = [
            for (final s in slots)
              if (s ~/ 60 == h) s,
          ];
          final keep = h * 60 + minuteValue;
          final next = opts.contains(keep) ? keep : opts.first;
          onChange(hours.applyMinutes(value, next));
        },
      ),
      ComboBox<int>(
        isExpanded: true,
        value: minuteValue,
        items: [
          for (final m in minutesThisHour)
            ComboBoxItem<int>(
              value: m,
              child: Text(ClinicHours.formatClock(selectedHour * 60 + m)),
            ),
        ],
        onChanged: (m) {
          if (m == null) return;
          onChange(hours.applyMinutes(value, selectedHour * 60 + m));
        },
      ),
    ]);
  }
}
