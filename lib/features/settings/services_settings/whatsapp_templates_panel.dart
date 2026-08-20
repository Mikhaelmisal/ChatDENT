import 'package:chatdent/common_widgets/button_styles.dart';
import 'package:chatdent/features/leads/whatsapp_templates.dart';
import 'package:chatdent/features/settings/applies_to_indicator.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/cupertino.dart';

class WhatsAppTemplatesPanel extends StatefulWidget {
  const WhatsAppTemplatesPanel({super.key});

  @override
  State<WhatsAppTemplatesPanel> createState() => _WhatsAppTemplatesPanelState();
}

class _WhatsAppTemplatesPanelState extends State<WhatsAppTemplatesPanel> {
  late WhatsAppTemplates templates;
  String _id = WhatsAppTemplateIds.welcome;
  late final TextEditingController _body;

  static const _labelKeys = {
    WhatsAppTemplateIds.welcome: 'tplWelcome',
    WhatsAppTemplateIds.confirm: 'whatsappConfirmTemplate',
    WhatsAppTemplateIds.history: 'tplHistory',
    WhatsAppTemplateIds.aftercare: 'tplAftercare',
    WhatsAppTemplateIds.remind: 'whatsappRemindTemplate',
    WhatsAppTemplateIds.birthday: 'birthdayTemplate',
    WhatsAppTemplateIds.review: 'reviewTemplate',
    WhatsAppTemplateIds.alertNew: 'tplAlertNew',
    WhatsAppTemplateIds.alertBack: 'tplAlertBack',
    WhatsAppTemplateIds.optOut: 'tplOptOut',
  };

  @override
  void initState() {
    super.initState();
    ensureWhatsAppTemplates();
    templates = loadWhatsAppTemplates();
    _body = TextEditingController(text: templates.bodyOf(_id));
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  void _pick(String? id) {
    if (id == null) return;
    _id = id;
    _body.text = templates.bodyOf(id);
    setState(() {});
  }

  void _save() {
    templates = templates.withBody(_id, _body.text);
    persistWhatsAppTemplates(templates);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Expander(
        leading: const Icon(FluentIcons.text_document),
        header: Txt(txt('whatsappTemplates')),
        trailing: const AppliesToIndicator(scope: Scope.app),
        contentPadding: const EdgeInsets.all(10),
        content: SizedBox(
          width: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              InfoBar(
                title: Txt(txt('whatsappTemplatesInfo')),
                severity: InfoBarSeverity.info,
              ),
              ComboBox<String>(
                isExpanded: true,
                value: _id,
                items: [
                  for (final id in WhatsAppTemplateIds.allIds)
                    ComboBoxItem(
                      value: id,
                      child: Text(txt(_labelKeys[id] ?? id)),
                    ),
                ],
                onChanged: _pick,
              ),
              CupertinoTextField(
                controller: _body,
                maxLines: 14,
                placeholder: txt('campaignMessageBody'),
              ),
              Text(
                txt('templatePlaceholders'),
                style: FluentTheme.of(context).typography.caption,
              ),
              FilledButton(
                onPressed: _save,
                child: ButtonContent(WindowsIcons.save, txt('save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
