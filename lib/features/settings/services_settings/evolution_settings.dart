import 'package:chatdent/common_widgets/button_styles.dart';
import 'package:chatdent/features/leads/clinic_hours.dart';
import 'package:chatdent/features/settings/applies_to_indicator.dart';
import 'package:chatdent/features/settings/settings_model.dart';
import 'package:chatdent/features/settings/settings_stores.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/cupertino.dart';

class EvolutionSettingsPanel extends StatefulWidget {
  const EvolutionSettingsPanel({super.key});

  @override
  State<EvolutionSettingsPanel> createState() => _EvolutionSettingsPanelState();
}

class _EvolutionSettingsPanelState extends State<EvolutionSettingsPanel> {
  late final TextEditingController baseUrl;
  late final TextEditingController apiKey;
  late final TextEditingController instance;
  late final TextEditingController clinicName;
  late final TextEditingController clinicPhone;
  late final TextEditingController maps;
  late EvolutionSettings _loaded;
  late final TextEditingController staffGroup;
  late final TextEditingController mkt1;
  late final TextEditingController mkt2;
  late final TextEditingController mkt3;
  late final TextEditingController mkt4;
  late final TextEditingController address;
  final showKey = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _loaded = EvolutionSettings.fromJsonString(
        globalSettings.get(EvolutionSettings.settingId).value);
    final e = _loaded;
    baseUrl = TextEditingController(text: e.baseUrl);
    apiKey = TextEditingController(text: e.apiKey);
    instance = TextEditingController(text: e.instance);
    clinicName = TextEditingController(text: e.clinicName);
    clinicPhone = TextEditingController(text: globalSettings.phone);
    maps = TextEditingController(text: e.googleMapsUrl);
    staffGroup = TextEditingController(text: e.staffGroupJid);
    mkt1 = TextEditingController(text: e.marketing1);
    mkt2 = TextEditingController(text: e.marketing2);
    mkt3 = TextEditingController(text: e.marketing3);
    mkt4 = TextEditingController(text: e.marketing4);
    address = TextEditingController(text: e.clinicAddress);
  }

  @override
  void dispose() {
    baseUrl.dispose();
    apiKey.dispose();
    instance.dispose();
    clinicName.dispose();
    clinicPhone.dispose();
    maps.dispose();
    staffGroup.dispose();
    mkt1.dispose();
    mkt2.dispose();
    mkt3.dispose();
    mkt4.dispose();
    address.dispose();
    showKey.dispose();
    super.dispose();
  }

  void _save() {
    globalSettings.set(Setting.fromJson({
      'id': 'phone__________',
      'value': clinicPhone.text.trim(),
    }));
    globalSettings.set(Setting.fromJson({
      'id': EvolutionSettings.settingId,
      'value': EvolutionSettings(
        baseUrl: baseUrl.text.trim(),
        apiKey: apiKey.text.trim(),
        instance: instance.text.trim(),
        clinicName: clinicName.text.trim().isEmpty
            ? 'the clinic'
            : clinicName.text.trim(),
        confirmTemplate: _loaded.confirmTemplate,
        remindTemplate: _loaded.remindTemplate,
        googleMapsUrl: maps.text.trim(),
        staffGroupJid: staffGroup.text.trim().isEmpty
            ? '120363426681576301@g.us'
            : staffGroup.text.trim(),
        marketing1: mkt1.text.trim(),
        marketing2: mkt2.text.trim(),
        marketing3: mkt3.text.trim(),
        marketing4: mkt4.text.trim(),
        clinicAddress: address.text.trim(),
      ).toJsonString(),
    }));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Expander(
        leading: const Icon(WindowsIcons.message),
        header: Txt(txt('evolutionWhatsapp')),
        trailing: const AppliesToIndicator(scope: Scope.app),
        contentPadding: const EdgeInsets.all(10),
        content: SizedBox(
          width: 480,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              InfoBar(
                title: Txt(txt('evolutionWhatsappInfo')),
                severity: InfoBarSeverity.info,
              ),
              InfoLabel(
                label: txt('evolutionBaseUrl'),
                child: CupertinoTextField(
                  controller: baseUrl,
                  placeholder: 'https://evolution.example.com',
                ),
              ),
              InfoLabel(
                label: txt('evolutionApiKey'),
                child: ValueListenableBuilder(
                  valueListenable: showKey,
                  builder: (context, show, _) {
                    return CupertinoTextField(
                      controller: apiKey,
                      obscureText: !show,
                      suffix: IconButton(
                        icon: Icon(show
                            ? FluentIcons.red_eye
                            : FluentIcons.view),
                        onPressed: () => showKey.value = !show,
                      ),
                    );
                  },
                ),
              ),
              InfoLabel(
                label: txt('evolutionInstance'),
                child: CupertinoTextField(controller: instance),
              ),
              InfoLabel(
                label: txt('clinicName'),
                child: CupertinoTextField(controller: clinicName),
              ),
              InfoLabel(
                label: txt('clinicPhonePatients'),
                child: CupertinoTextField(
                  controller: clinicPhone,
                  placeholder: '+91 86001 06020',
                ),
              ),
              Text(txt('clinicPhonePatientsHint'),
                  style: FluentTheme.of(context).typography.caption),
              InfoLabel(
                label: txt('clinicAddress'),
                child: CupertinoTextField(controller: address, maxLines: 3),
              ),
              InfoLabel(
                label: txt('googleMapsUrl'),
                child: CupertinoTextField(
                  controller: maps,
                  placeholder: 'https://maps.app.goo.gl/...',
                ),
              ),
              InfoLabel(
                label: txt('staffWhatsappGroup'),
                child: CupertinoTextField(
                  controller: staffGroup,
                  placeholder: '120363426681576301@g.us',
                ),
              ),
              Text(txt('marketingInstancesHint'),
                  style: FluentTheme.of(context).typography.caption),
              InfoLabel(
                label: '${txt('marketingInstance')} 1',
                child: CupertinoTextField(
                  controller: mkt1,
                  placeholder: 'clinic_mkt_1',
                ),
              ),
              InfoLabel(
                label: '${txt('marketingInstance')} 2',
                child: CupertinoTextField(controller: mkt2),
              ),
              InfoLabel(
                label: '${txt('marketingInstance')} 3',
                child: CupertinoTextField(controller: mkt3),
              ),
              InfoLabel(
                label: '${txt('marketingInstance')} 4',
                child: CupertinoTextField(controller: mkt4),
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
