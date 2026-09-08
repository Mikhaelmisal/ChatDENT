import 'package:chatdent/common_widgets/button_styles.dart';
import 'package:chatdent/common_widgets/screen_command_bar.dart';
import 'package:chatdent/features/prescriptions/medicine_catalog.dart';
import 'package:chatdent/features/settings/applies_to_indicator.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/cupertino.dart';

/// Clinic medicine catalog — search, add, remove. Lives in Settings.
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

  Future<void> _openAddDialog() async {
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
  }

  Future<void> _resetDefaults() async {
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
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Expander(
        leading: const Icon(FluentIcons.pill),
        header: Txt(txt('prescriptions')),
        trailing: const AppliesToIndicator(scope: Scope.app),
        contentPadding: const EdgeInsets.all(10),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            InfoBar(
              title: Txt(txt('prescriptionsTabInfo')),
              severity: InfoBarSeverity.info,
            ),
            Row(
              spacing: 8,
              children: [
                Button(
                  onPressed: _openAddDialog,
                  child: ButtonContent(WindowsIcons.add, txt('addMedicine')),
                ),
                Button(
                  onPressed: _resetDefaults,
                  child: ButtonContent(FluentIcons.reset, txt('resetDefaults')),
                ),
              ],
            ),
            CupertinoTextField(
              controller: _search,
              placeholder: '${txt('searchMedicines')}...',
              prefix: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(FluentIcons.search),
              ),
              onChanged: (_) => _reload(),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: Container(
                decoration: topBarDecoration(context, Colors.grey),
                child: _medicines.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(child: Txt(txt('noMedicinesFound'))),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
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
        ),
      ),
    );
  }
}
