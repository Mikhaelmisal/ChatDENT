import 'dart:convert';

import 'package:chatdent/common_widgets/button_styles.dart';
import 'package:chatdent/common_widgets/dialogs/close_dialog_button.dart';
import 'package:chatdent/common_widgets/dialogs/dialog_styling.dart';
import 'package:chatdent/common_widgets/keyboard_aware.dart';
import 'package:chatdent/features/leads/lead_csv.dart';
import 'package:chatdent/features/leads/leads_store.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/cupertino.dart';

class ImportLeadsDialog extends StatefulWidget {
  const ImportLeadsDialog({super.key});

  @override
  State<ImportLeadsDialog> createState() => _ImportLeadsDialogState();
}

class _ImportLeadsDialogState extends State<ImportLeadsDialog> {
  final controller = FlyoutController();
  final csvController = TextEditingController();
  String? fileName;
  String? importSummary;
  bool importing = false;

  @override
  void dispose() {
    controller.dispose();
    csvController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    csvController.addListener(() => setState(() {}));
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return;
    String text;
    try {
      text = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      text = latin1.decode(bytes);
    }
    csvController.text = text;
    setState(() {
      fileName = file.name;
      importSummary = null;
    });
  }

  void _import() {
    if (csvController.text.trim().isEmpty) return;
    setState(() => importing = true);
    final result = parseLeadsCsv(
      csvController.text,
      existingPhones: leads.existingPhoneKeys,
    );
    for (final lead in result.leads) {
      leads.set(lead);
    }
    setState(() {
      importing = false;
      importSummary =
          '${txt("leadsImported")}: ${result.imported}. ${txt("leadsSkipped")}: ${result.skippedEmpty + result.skippedDuplicate}.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardAwareView(
      child: ContentDialog(
        style: dialogStyling(context, false, true),
        actions: [
          FilledButton(
            style: csvController.text.isEmpty
                ? filledButtonStyle(Colors.grey.withAlpha(100))
                : null,
            onPressed: csvController.text.isEmpty || importing ? null : _import,
            child: ButtonContent(
              WindowsIcons.copy,
              txt('import'),
              inProgress: importing,
            ),
          ),
          const CloseButtonInDialog(buttonText: 'close'),
        ],
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Txt(txt('importCsv')),
            FlyoutTarget(
              controller: controller,
              child: Button(
                child: ButtonContent(WindowsIcons.info, txt('howToUse')),
                onPressed: () {
                  controller.showFlyout(
                    builder: (ctx) {
                      return TeachingTip(
                        title: Txt(txt('importCsv')),
                        subtitle: Txt(txt('csvImportHowTo')),
                      );
                    },
                  );
                },
              ),
            ),
            IconButton(
              icon: const Icon(WindowsIcons.cancel),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Button(
              onPressed: _pickFile,
              child: ButtonContent(
                FluentIcons.open_file,
                fileName == null
                    ? txt('pickCsvFile')
                    : '${txt("csvFile")}: $fileName',
              ),
            ),
            Txt(txt('csvPasteHint')),
            CupertinoTextField(
              maxLines: 6,
              controller: csvController,
              placeholder: 'name,phone,email,source,campaign,interest,notes,stage',
            ),
            if (importSummary != null)
              InfoBar(
                title: Text(importSummary!),
                severity: InfoBarSeverity.success,
              ),
          ],
        ),
      ),
    );
  }
}
