import 'dart:math';

import 'package:chatdent/common_widgets/button_styles.dart';
import 'package:chatdent/core/multi_stream_builder.dart';
import 'package:chatdent/features/accounts/accounts_controller.dart';
import 'package:chatdent/features/leads/clinic_hours.dart';
import 'package:chatdent/features/settings/applies_to_indicator.dart';
import 'package:chatdent/features/settings/services_settings/responsive_row.dart';
import 'package:chatdent/features/settings/settings_model.dart';
import 'package:chatdent/features/settings/settings_stores.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:chatdent/utils/constants.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/cupertino.dart';

const _weekdayKeys = {
  1: 'monday',
  2: 'tuesday',
  3: 'wednesday',
  4: 'thursday',
  5: 'friday',
  6: 'saturday',
  7: 'sunday',
};

final _timeChoices = List<int>.generate(28, (i) => 480 + i * 30); // 08:00–21:30

DayHours get _defaultDay => DayHours.sessions(
      morningOpen: 600,
      morningClose: 840,
      eveningOpen: 1020,
      eveningClose: 1140,
    );

class ClinicHoursSettings extends StatefulWidget {
  const ClinicHoursSettings({super.key});

  @override
  State<ClinicHoursSettings> createState() => _ClinicHoursSettingsState();
}

class _ClinicHoursSettingsState extends State<ClinicHoursSettings> {
  late ClinicHours hours;
  final closedController = TextEditingController();
  final tokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    hours = ClinicHours.fromJsonString(
        globalSettings.get(ClinicHours.settingId).value);
    closedController.text = hours.closedDates.join(', ');
    tokenController.text = globalSettings.get(ClinicHours.tokenSettingId).value;
  }

  @override
  void dispose() {
    closedController.dispose();
    tokenController.dispose();
    super.dispose();
  }

  void _save() {
    final closed = closedController.text
        .split(RegExp(r'[,;\s]+'))
        .map((s) => s.trim())
        .where((s) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s))
        .toList();
    hours = hours.copyWith(closedDates: closed);
    globalSettings.set(Setting.fromJson({
      'id': ClinicHours.settingId,
      'value': hours.toJsonString(),
    }));
    var token = tokenController.text.trim();
    if (token.isEmpty) {
      token = _newToken();
      tokenController.text = token;
    }
    globalSettings.set(Setting.fromJson({
      'id': ClinicHours.tokenSettingId,
      'value': token,
    }));
    setState(() {});
  }

  String _newToken() {
    const chars = alphabet;
    final rand = Random.secure();
    return List.generate(24, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  int _nearestChoice(int minutes) {
    return _timeChoices.reduce(
      (a, b) => (a - minutes).abs() <= (b - minutes).abs() ? a : b,
    );
  }

  void _setDay(int weekday, DayHours? day) {
    final next = Map<int, DayHours?>.from(hours.week);
    next[weekday] = day;
    setState(() => hours = hours.copyWith(week: next));
  }

  DayHours _normalized({
    required DayHours day,
    int? morningOpen,
    int? morningClose,
    int? eveningOpen,
    int? eveningClose,
    bool? eveningOn,
  }) {
    var mOpen = _nearestChoice(morningOpen ?? day.morningOpen);
    var mClose = _nearestChoice(morningClose ?? day.morningClose);
    final on = eveningOn ?? day.hasEvening;
    var eOpen = _nearestChoice(eveningOpen ?? day.eveningOpen ?? 1020);
    var eClose = _nearestChoice(eveningClose ?? day.eveningClose ?? 1140);
    if (mClose <= mOpen) mClose = mOpen + 30;
    if (on) {
      if (eOpen < mClose) eOpen = mClose;
      if (eClose <= eOpen) eClose = eOpen + 30;
    }
    return DayHours.sessions(
      morningOpen: mOpen,
      morningClose: mClose,
      eveningOpen: on ? eOpen : null,
      eveningClose: on ? eClose : null,
    );
  }

  Widget _timeBox({
    required String label,
    required int value,
    required void Function(int) onChanged,
  }) {
    final snapped = _nearestChoice(value);
    return InfoLabel(
      label: label,
      child: ComboBox<int>(
        isExpanded: true,
        value: snapped,
        items: [
          ..._timeChoices.map(
            (m) => ComboBoxItem<int>(
              value: m,
              child: Text(ClinicHours.formatMinutes(m)),
            ),
          ),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _dayBlock(int weekday) {
    final day = hours.week[weekday];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      decoration: BoxDecoration(
        border: Border.all(
          color: FluentTheme.of(context).resources.controlStrokeColorDefault,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Checkbox(
            checked: day != null,
            content: Txt(txt(_weekdayKeys[weekday]!)),
            onChanged: (on) =>
                _setDay(weekday, on == true ? _defaultDay : null),
          ),
          if (day != null) ...[
            Txt(txt('morningHours')),
            ResponsiveRow(children: [
              _timeBox(
                label: txt('fromTime'),
                value: day.morningOpen,
                onChanged: (v) => _setDay(
                  weekday,
                  _normalized(day: day, morningOpen: v),
                ),
              ),
              _timeBox(
                label: txt('toTime'),
                value: day.morningClose,
                onChanged: (v) => _setDay(
                  weekday,
                  _normalized(day: day, morningClose: v),
                ),
              ),
            ]),
            Checkbox(
              checked: day.hasEvening,
              content: Txt(txt('eveningSession')),
              onChanged: (on) => _setDay(
                weekday,
                _normalized(day: day, eveningOn: on == true),
              ),
            ),
            if (day.hasEvening) ...[
              Txt(txt('eveningHours')),
              ResponsiveRow(children: [
                _timeBox(
                  label: txt('fromTime'),
                  value: day.eveningOpen ?? 1020,
                  onChanged: (v) => _setDay(
                    weekday,
                    _normalized(day: day, eveningOpen: v),
                  ),
                ),
                _timeBox(
                  label: txt('toTime'),
                  value: day.eveningClose ?? 1140,
                  onChanged: (v) => _setDay(
                    weekday,
                    _normalized(day: day, eveningClose: v),
                  ),
                ),
              ]),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Expander(
        leading: const Icon(FluentIcons.date_time),
        header: Txt(txt('clinicHours')),
        trailing: const AppliesToIndicator(scope: Scope.app),
        contentPadding: const EdgeInsets.all(10),
        content: SizedBox(
          width: 560,
          child: MStreamBuilder(
            streams: [accounts.list.stream],
            builder: (context, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 10,
                children: [
                  InfoBar(
                    title: Txt(txt('clinicHoursInfo')),
                    severity: InfoBarSeverity.info,
                    isLong: true,
                  ),
                  ResponsiveRow(children: [
                    InfoLabel(
                      label: txt('slotLength'),
                      child: ComboBox<int>(
                        isExpanded: true,
                        value: const {15, 20, 30, 45, 60}
                                .contains(hours.slotMinutes)
                            ? hours.slotMinutes
                            : 20,
                        items: const [
                          ComboBoxItem(value: 15, child: Text('15')),
                          ComboBoxItem(value: 20, child: Text('20')),
                          ComboBoxItem(value: 30, child: Text('30')),
                          ComboBoxItem(value: 45, child: Text('45')),
                          ComboBoxItem(value: 60, child: Text('60')),
                        ],
                        onChanged: (v) => setState(() {
                          hours = hours.copyWith(slotMinutes: v);
                        }),
                      ),
                    ),
                    InfoLabel(
                      label: txt('utcOffsetMinutes'),
                      child: ComboBox<int>(
                        isExpanded: true,
                        value: hours.utcOffsetMinutes,
                        items: const [
                          ComboBoxItem(value: 330, child: Text('IST +05:30')),
                          ComboBoxItem(value: 0, child: Text('UTC +00:00')),
                          ComboBoxItem(value: 180, child: Text('+03:00')),
                          ComboBoxItem(value: 240, child: Text('+04:00')),
                        ],
                        onChanged: (v) => setState(() {
                          hours = hours.copyWith(utcOffsetMinutes: v);
                        }),
                      ),
                    ),
                  ]),
                  InfoLabel(
                    label: txt('defaultBookingDoctor'),
                    child: ComboBox<String>(
                      isExpanded: true,
                      value: hours.defaultOperatorId.isNotEmpty &&
                              accounts.operators.any(
                                  (a) => a.id == hours.defaultOperatorId)
                          ? hours.defaultOperatorId
                          : '',
                      items: [
                        ComboBoxItem(value: '', child: Txt(txt('any'))),
                        ...accounts.operators.map(
                          (a) => ComboBoxItem(
                            value: a.id,
                            child: Text(accounts.name(a)),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() {
                        hours = hours.copyWith(defaultOperatorId: v ?? '');
                      }),
                    ),
                  ),
                  ...[1, 2, 3, 4, 5, 6, 7].map(_dayBlock),
                  InfoLabel(
                    label: txt('closedDates'),
                    child: CupertinoTextField(
                      controller: closedController,
                      placeholder: '2026-10-02, 2026-12-25',
                    ),
                  ),
                  InfoLabel(
                    label: txt('bookingApiToken'),
                    child: CupertinoTextField(
                      controller: tokenController,
                      placeholder: txt('bookingApiTokenHint'),
                      suffix: IconButton(
                        icon: const Icon(FluentIcons.reset),
                        onPressed: () {
                          tokenController.text = _newToken();
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: _save,
                    child: ButtonContent(WindowsIcons.save, txt('save')),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
