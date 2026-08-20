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
    hours = ClinicHours(
      week: hours.week,
      utcOffsetMinutes: hours.utcOffsetMinutes,
      slotMinutes: hours.slotMinutes,
      defaultOperatorId: hours.defaultOperatorId,
      closedDates: closed,
    );
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

  Widget _timeBox({
    required String label,
    required int? value,
    required void Function(int?) onChanged,
    bool allowClosed = false,
  }) {
    return InfoLabel(
      label: label,
      child: ComboBox<int?>(
        isExpanded: true,
        value: value,
        items: [
          if (allowClosed)
            ComboBoxItem<int?>(value: null, child: Txt(txt('closed'))),
          ..._timeChoices.map(
            (m) => ComboBoxItem<int?>(
              value: m,
              child: Text(ClinicHours.formatMinutes(m)),
            ),
          ),
        ],
        onChanged: onChanged,
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
          width: 520,
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
                  ),
                  ResponsiveRow(children: [
                    InfoLabel(
                      label: txt('slotLength'),
                      child: ComboBox<int>(
                        isExpanded: true,
                        value: hours.slotMinutes,
                        items: const [
                          ComboBoxItem(value: 15, child: Text('15')),
                          ComboBoxItem(value: 30, child: Text('30')),
                          ComboBoxItem(value: 45, child: Text('45')),
                          ComboBoxItem(value: 60, child: Text('60')),
                        ],
                        onChanged: (v) => setState(() {
                          hours = ClinicHours(
                            week: hours.week,
                            utcOffsetMinutes: hours.utcOffsetMinutes,
                            slotMinutes: v ?? hours.slotMinutes,
                            defaultOperatorId: hours.defaultOperatorId,
                            closedDates: hours.closedDates,
                          );
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
                          hours = ClinicHours(
                            week: hours.week,
                            utcOffsetMinutes: v ?? hours.utcOffsetMinutes,
                            slotMinutes: hours.slotMinutes,
                            defaultOperatorId: hours.defaultOperatorId,
                            closedDates: hours.closedDates,
                          );
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
                        hours = ClinicHours(
                          week: hours.week,
                          utcOffsetMinutes: hours.utcOffsetMinutes,
                          slotMinutes: hours.slotMinutes,
                          defaultOperatorId: v ?? '',
                          closedDates: hours.closedDates,
                        );
                      }),
                    ),
                  ),
                  ...[1, 2, 3, 4, 5, 6, 7].map((d) {
                    final day = hours.week[d];
                    return ResponsiveRow(children: [
                      SizedBox(
                        width: 90,
                        child: Checkbox(
                          checked: day != null,
                          content: Txt(txt(_weekdayKeys[d]!)),
                          onChanged: (on) => setState(() {
                            final next = Map<int, DayHours?>.from(hours.week);
                            next[d] = on == true
                                ? const DayHours(
                                    open: 600,
                                    close: 1140,
                                    breakStart: 810,
                                    breakEnd: 870,
                                  )
                                : null;
                            hours = ClinicHours(
                              week: next,
                              utcOffsetMinutes: hours.utcOffsetMinutes,
                              slotMinutes: hours.slotMinutes,
                              defaultOperatorId: hours.defaultOperatorId,
                              closedDates: hours.closedDates,
                            );
                          }),
                        ),
                      ),
                      if (day != null)
                        _timeBox(
                          label: txt('opens'),
                          value: day.open,
                          onChanged: (v) => setState(() {
                            final next = Map<int, DayHours?>.from(hours.week);
                            next[d] = DayHours(
                              open: v ?? day.open,
                              close: day.close,
                              breakStart: day.breakStart,
                              breakEnd: day.breakEnd,
                            );
                            hours = ClinicHours(
                              week: next,
                              utcOffsetMinutes: hours.utcOffsetMinutes,
                              slotMinutes: hours.slotMinutes,
                              defaultOperatorId: hours.defaultOperatorId,
                              closedDates: hours.closedDates,
                            );
                          }),
                        ),
                      if (day != null)
                        _timeBox(
                          label: txt('closes'),
                          value: day.close,
                          onChanged: (v) => setState(() {
                            final next = Map<int, DayHours?>.from(hours.week);
                            next[d] = DayHours(
                              open: day.open,
                              close: v ?? day.close,
                              breakStart: day.breakStart,
                              breakEnd: day.breakEnd,
                            );
                            hours = ClinicHours(
                              week: next,
                              utcOffsetMinutes: hours.utcOffsetMinutes,
                              slotMinutes: hours.slotMinutes,
                              defaultOperatorId: hours.defaultOperatorId,
                              closedDates: hours.closedDates,
                            );
                          }),
                        ),
                    ]);
                  }),
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
