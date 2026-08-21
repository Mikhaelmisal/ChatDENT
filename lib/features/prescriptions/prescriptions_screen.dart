import 'package:chatdent/common_widgets/button_styles.dart';
import 'package:chatdent/common_widgets/screen_command_bar.dart';
import 'package:chatdent/features/prescriptions/medicine_catalog.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:chatdent/utils/constants.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/cupertino.dart';

/// Catalog of clinic medicines — search, add, remove (like a dedicated tab).
class PrescriptionsScreen extends StatefulWidget {
  const PrescriptionsScreen({super.key});

  @override
  State<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends State<PrescriptionsScreen> {
  final _search = TextEditingController();
  final _add = TextEditingController();
  List<String> _medicines = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    _add.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _medicines = MedicineCatalog.search(_search.text);
    });
  }

  Future<void> _addMedicine() async {
    final name = _add.text.trim();
    if (name.isEmpty) return;
    MedicineCatalog.addMedicine(name);
    _add.clear();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenCommandBar(
          mainButton: IconButton(
            icon: ButtonContent(WindowsIcons.add, txt('addMedicine')),
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (ctx) => ContentDialog(
                  title: Txt(txt('addMedicine')),
                  content: CupertinoTextField(
                    controller: _add,
                    placeholder: txt('medicineName'),
                    autofocus: true,
                    onSubmitted: (_) {
                      Navigator.pop(ctx);
                      _addMedicine();
                    },
                  ),
                  actions: [
                    Button(
                      child: Txt(txt('cancel')),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    FilledButton(
                      child: Txt(txt('add')),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _addMedicine();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          otherButtons: [
            IconButton(
              icon: ButtonContent(FluentIcons.reset, txt('resetDefaults')),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => ContentDialog(
                    title: Txt(txt('resetDefaults')),
                    content: Txt(txt('resetMedicinesConfirm')),
                    actions: [
                      Button(
                        child: Txt(txt('cancel')),
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                      FilledButton(
                        child: Txt(txt('resetDefaults')),
                        onPressed: () => Navigator.pop(ctx, true),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  MedicineCatalog.resetToDefaults();
                  _reload();
                }
              },
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: InfoBar(
            title: Txt(txt('prescriptionsTabInfo')),
            severity: InfoBarSeverity.info,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: CupertinoTextField(
            controller: _search,
            placeholder: '${txt('searchMedicines')}...',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(FluentIcons.search),
            ),
            onChanged: (_) => _reload(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: topBarDecoration(context, Colors.grey),
            child: _medicines.isEmpty
                ? Center(child: Txt(txt('noMedicinesFound')))
                : ListView.separated(
                    itemCount: _medicines.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, i) {
                      final name = _medicines[i];
                      return ListTile(
                        title: Txt(name),
                        trailing: IconButton(
                          icon: const Icon(FluentIcons.delete),
                          onPressed: () {
                            MedicineCatalog.removeMedicine(name);
                            _reload();
                          },
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
