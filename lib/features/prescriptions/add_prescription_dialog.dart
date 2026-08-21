import 'package:chatdent/common_widgets/button_styles.dart';
import 'package:chatdent/features/prescriptions/medicine_catalog.dart';
import 'package:chatdent/features/prescriptions/prescription_line.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';

/// Search medicine + times of day + before/after meal, return a stored line.
Future<String?> showAddPrescriptionDialog(BuildContext context) async {
  final medicineCtrl = TextEditingController();
  String duration = '5 days';
  MealTiming meal = MealTiming.afterMeal;
  final times = <_DoseTime>{_DoseTime.morning};
  final catalog = MedicineCatalog.load();

  final result = await showDialog<String>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return ContentDialog(
            title: Txt(txt('addPrescription')),
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 14,
              children: [
                InfoLabel(
                  label: txt('medicineName'),
                  child: AutoSuggestBox<String>(
                    controller: medicineCtrl,
                    placeholder: txt('searchMedicines'),
                    items: catalog
                        .map((m) =>
                            AutoSuggestBoxItem<String>(value: m, label: m))
                        .toList(),
                    onSelected: (item) {
                      medicineCtrl.text = item.value ?? '';
                    },
                    onChanged: (text, _) {},
                  ),
                ),
                InfoLabel(
                  label: txt('Dose Times'),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in _DoseTime.values)
                        ToggleButton(
                          checked: times.contains(t),
                          onChanged: (on) {
                            setLocal(() {
                              if (on) {
                                times.add(t);
                              } else if (times.length > 1) {
                                times.remove(t);
                              }
                            });
                          },
                          child: ButtonContent(t.icon, txt(t.labelKey)),
                        ),
                    ],
                  ),
                ),
                InfoLabel(
                  label: txt('duration'),
                  child: ComboBox<String>(
                    isExpanded: true,
                    value: duration,
                    items: const [
                      '3 days',
                      '5 days',
                      '7 days',
                      '10 days',
                      '14 days',
                      '1 month',
                      'as needed',
                    ]
                        .map((d) => ComboBoxItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setLocal(() => duration = v);
                    },
                  ),
                ),
                InfoLabel(
                  label: txt('mealTiming'),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ToggleButton(
                        checked: meal == MealTiming.beforeMeal,
                        onChanged: (on) {
                          if (on) {
                            setLocal(() => meal = MealTiming.beforeMeal);
                          }
                        },
                        child: ButtonContent(
                          FluentIcons.breakfast,
                          txt('beforeMeals'),
                        ),
                      ),
                      ToggleButton(
                        checked: meal == MealTiming.afterMeal,
                        onChanged: (on) {
                          if (on) {
                            setLocal(() => meal = MealTiming.afterMeal);
                          }
                        },
                        child: ButtonContent(
                          FluentIcons.diet_plan_notebook,
                          txt('afterMeals'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              Button(
                child: Txt(txt('cancel')),
                onPressed: () => Navigator.pop(ctx),
              ),
              FilledButton(
                child: Txt(txt('add')),
                onPressed: () {
                  if (times.isEmpty) return;
                  final ordered = _DoseTime.values
                      .where(times.contains)
                      .map((t) => txt(t.labelKey))
                      .join(', ');
                  final line = PrescriptionLine(
                    medicine: medicineCtrl.text.trim(),
                    dose: ordered,
                    duration: duration,
                    meal: meal,
                  );
                  if (!line.isValid) return;
                  MedicineCatalog.addMedicine(line.medicine);
                  Navigator.pop(ctx, line.toStored());
                },
              ),
            ],
          );
        },
      );
    },
  );

  medicineCtrl.dispose();
  return result;
}

enum _DoseTime { morning, afternoon, evening }

extension on _DoseTime {
  String get labelKey {
    switch (this) {
      case _DoseTime.morning:
        return 'Morning';
      case _DoseTime.afternoon:
        return 'Afternoon';
      case _DoseTime.evening:
        return 'Evening';
    }
  }

  IconData get icon {
    switch (this) {
      case _DoseTime.morning:
        return FluentIcons.sunny;
      case _DoseTime.afternoon:
        return FluentIcons.partly_cloudy_day;
      case _DoseTime.evening:
        return FluentIcons.clear_night;
    }
  }
}
