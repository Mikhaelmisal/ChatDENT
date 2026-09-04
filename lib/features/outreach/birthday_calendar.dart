import 'package:chatdent/common_widgets/contact_buttons.dart';
import 'package:chatdent/common_widgets/item_title.dart';
import 'package:chatdent/common_widgets/screen_command_bar.dart';
import 'package:chatdent/common_widgets/swipe_detector.dart';
import 'package:chatdent/features/appointments/calendar_widget.dart';
import 'package:chatdent/features/outreach/campaign_settings.dart';
import 'package:chatdent/features/patients/open_patient_panel.dart';
import 'package:chatdent/features/patients/patient_model.dart';
import 'package:chatdent/features/patients/patients_store.dart';
import 'package:chatdent/features/settings/settings_stores.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:chatdent/utils/colors_without_yellow.dart';
import 'package:fluent_ui/fluent_ui.dart' hide Card;
import 'package:flutter/material.dart' show Card;
import 'package:table_calendar/table_calendar.dart';

bool birthdayOnDay(DateTime birth, DateTime day) {
  if (birth.year < 1000) return false;
  if (birth.month == 2 && birth.day == 29) {
    final leap = DateTime(day.year, 2, 29).month == 2;
    if (!leap) return day.month == 2 && day.day == 28;
  }
  return birth.month == day.month && birth.day == day.day;
}

class BirthdayAgendaCalendar extends StatefulWidget {
  const BirthdayAgendaCalendar({super.key});

  @override
  State<BirthdayAgendaCalendar> createState() => _BirthdayAgendaCalendarState();
}

class _BirthdayAgendaCalendarState extends State<BirthdayAgendaCalendar> {
  CalendarFormat calendarFormat = CalendarFormat.week;
  late DateTime selectedDate;
  final now = DateTime.now();

  double get calendarHeight {
    switch (calendarFormat) {
      case CalendarFormat.month:
        return 300;
      case CalendarFormat.twoWeeks:
        return 170;
      default:
        return 130;
    }
  }

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime(now.year, now.month, now.day);
  }

  List<Patient> get _withBirthdays {
    return patients.present.values.where((p) => p.hasFullBirthDate).toList();
  }

  List<Patient> _forDay(DateTime day) {
    return _withBirthdays.where((p) => birthdayOnDay(p.birthAsDate, day)).toList()
      ..sort((a, b) => a.title.compareTo(b.title));
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.day == b.day && a.month == b.month && a.year == b.year;

  @override
  Widget build(BuildContext context) {
    final items = _forDay(selectedDate);
    return Column(
      children: [
        Container(
          constraints: BoxConstraints(maxHeight: calendarHeight),
          child: Card(
            color: Colors.transparent,
            elevation: 0,
            child: TableCalendar(
              firstDay: now.subtract(const Duration(days: 9999)),
              lastDay: now.add(const Duration(days: 9999)),
              focusedDay: selectedDate,
              daysOfWeekVisible: true,
              rowHeight: 30,
              startingDayOfWeek: StartingDayOfWeek.values.firstWhere(
                (v) => v.name == globalSettings.startDayOfWeek,
                orElse: () => StartingDayOfWeek.monday,
              ),
              pageJumpingEnabled: true,
              selectedDayPredicate: (day) => _isSameDay(day, selectedDate),
              shouldFillViewport: true,
              calendarFormat: calendarFormat,
              onFormatChanged: (format) {
                setState(() => calendarFormat = format);
              },
              availableCalendarFormats: {
                CalendarFormat.twoWeeks: txt("twoWeeksAbbr"),
                CalendarFormat.month: txt("monthAbbr"),
                CalendarFormat.week: txt("weekAbbr"),
              },
              eventLoader: (day) => _forDay(day),
              headerStyle: HeaderStyle(
                formatButtonShowsNext: false,
                formatButtonTextStyle: const TextStyle(color: Colors.white),
                formatButtonDecoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.grey.toAccentColor().lightest,
                    Colors.grey.toAccentColor().light,
                  ]),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              calendarBuilders: CalendarBuilders(
                dowBuilder: (context, day) => Center(
                  child: Txt(
                    DF.jalaliDayOfWeekAbbr(day),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                headerTitleBuilder: (context, day) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Center(child: Txt(DF.jalaliMonthYear(day))),
                      const Divider(size: 20, direction: Axis.vertical),
                      if (!_isSameDay(day, DateTime.now()))
                        IconButton(
                          onPressed: () => setState(
                            () => selectedDate = DateTime(
                              now.year,
                              now.month,
                              now.day,
                            ),
                          ),
                          iconButtonMode: IconButtonMode.large,
                          icon: Row(
                            children: [
                              const Icon(FluentIcons.goto_today),
                              const SizedBox(width: 5),
                              Txt(txt("today")),
                            ],
                          ),
                          style: ButtonStyle(
                            padding: const WidgetStatePropertyAll(
                              EdgeInsets.all(8),
                            ),
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                                side: BorderSide(
                                  color: colorsWithoutYellow[
                                          DateTime.now().weekday - 1]
                                      .withValues(alpha: 1),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
                defaultBuilder: (context, day, focusedDay) {
                  return DayCell(day: day, type: DayCellType.normal);
                },
                todayBuilder: (context, day, focusedDay) {
                  return DayCell(day: day, type: DayCellType.today);
                },
                selectedBuilder: (context, day, focusedDay) {
                  return DayCell(day: day, type: DayCellType.selected);
                },
                markerBuilder: (context, day, events) {
                  return events.isEmpty
                      ? null
                      : AppointmentsNumberIndicator(events: events, day: day);
                },
              ),
              onDaySelected: (newDate, focusedDay) {
                setState(() => selectedDate = newDate);
              },
            ),
          ),
        ),
        const SizedBox(height: 1),
        Expanded(
          child: SwipeDetector(
            onSwipePrev: () => setState(() {
              selectedDate = selectedDate.subtract(const Duration(days: 1));
            }),
            onSwipeNext: () => setState(() {
              selectedDate = selectedDate.add(const Duration(days: 1));
            }),
            child: Column(
              children: [
                Container(
                  decoration: topBarDecoration(context, Colors.grey),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  height: 45,
                  child: Row(
                    children: [
                      Txt(
                        localSettings.calendarSystem == "persian"
                            ? " ${DF.jalaliCommonDate(selectedDate)}"
                            : " ${DF.commonDate(selectedDate)}",
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: InfoBar(
                            isLong: false,
                            isIconVisible: true,
                            severity: InfoBarSeverity.warning,
                            title: Txt(txt("noBirthdaysForThisDay")),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: items.length,
                          itemBuilder: (context, i) {
                            final p = items[i];
                            final days = daysUntilBirthday(
                                  p.birthAsDate,
                                  selectedDate,
                                ) ??
                                0;
                            final turning = selectedDate.year - p.birthYear;
                            return ListTile(
                              leading: ItemTitle(item: p),
                              title: Text(p.title),
                              subtitle: Text(
                                days == 0
                                    ? '${txt("birthdayToday")} · ${txt("age")} $turning'
                                    : '${txt("daysAway")}: $days',
                              ),
                              trailing: p.phone.isEmpty
                                  ? null
                                  : PhoneNumberButton(phoneNumbers: p.phone),
                              onPressed: () => openPatient(p),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
