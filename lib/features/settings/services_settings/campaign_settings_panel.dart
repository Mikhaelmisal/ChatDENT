import 'package:chatdent/common_widgets/button_styles.dart';
import 'package:chatdent/features/leads/clinic_hours.dart';
import 'package:chatdent/features/leads/campaign_settings.dart';
import 'package:chatdent/features/settings/applies_to_indicator.dart';
import 'package:chatdent/features/settings/settings_model.dart';
import 'package:chatdent/features/settings/settings_stores.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:chatdent/services/login.dart';
import 'package:chatdent/services/network.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/cupertino.dart';

class WhatsAppCampaignSettings extends StatefulWidget {
  const WhatsAppCampaignSettings({super.key});

  @override
  State<WhatsAppCampaignSettings> createState() =>
      _WhatsAppCampaignSettingsState();
}

class _WhatsAppCampaignSettingsState extends State<WhatsAppCampaignSettings> {
  late WhatsAppCampaign campaign;
  late final TextEditingController reviewUrl;
  late final TextEditingController model;
  late final TextEditingController marketingUrl;
  late final TextEditingController treatments;
  late final TextEditingController quietStart;
  late final TextEditingController quietEnd;
  String? _uploadMsg;

  @override
  void initState() {
    super.initState();
    campaign = WhatsAppCampaign.fromJsonString(globalSettings.campaignJson);
    reviewUrl = TextEditingController(text: campaign.googleReviewUrl);
    model = TextEditingController(text: campaign.openrouterModel);
    marketingUrl = TextEditingController(text: campaign.marketingImageUrl);
    treatments = TextEditingController(text: campaign.treatments);
    quietStart = TextEditingController(
        text: ClinicHours.formatMinutes(campaign.quietStart));
    quietEnd = TextEditingController(
        text: ClinicHours.formatMinutes(campaign.quietEnd));
  }

  @override
  void dispose() {
    reviewUrl.dispose();
    model.dispose();
    marketingUrl.dispose();
    treatments.dispose();
    quietStart.dispose();
    quietEnd.dispose();
    super.dispose();
  }

  WhatsAppCampaign _readForm() {
    return WhatsAppCampaign(
      googleReviewUrl: reviewUrl.text.trim(),
      sendFlyerWithChat: campaign.sendFlyerWithChat,
      flyerFile: campaign.flyerFile,
      openrouterModel: model.text.trim().isEmpty
          ? const WhatsAppCampaign().openrouterModel
          : model.text.trim(),
      birthdayTemplate: campaign.birthdayTemplate,
      reviewTemplate: campaign.reviewTemplate,
      marketingImageUrl: marketingUrl.text.trim(),
      treatments: treatments.text.trim(),
      quietStart: ClinicHours.parseMinutes(quietStart.text) ?? 1260,
      quietEnd: ClinicHours.parseMinutes(quietEnd.text) ?? 540,
    );
  }

  void _save([WhatsAppCampaign? next]) {
    campaign = next ?? _readForm();
    globalSettings.set(Setting.fromJson({
      'id': WhatsAppCampaign.settingId,
      'value': campaign.toJsonString(),
    }));
    setState(() {});
  }

  Future<void> _pickFlyer() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    final name = result?.files.single.name;
    if (path == null || name == null || !login.isAdmin) return;
    setState(() => _uploadMsg = txt('uploadingFile'));
    try {
      globalSettings.set(Setting.fromJson({
        'id': WhatsAppCampaign.flyerRecordId,
        'value': name,
      }));
      final pbName = await globalSettings.uploadImg(
        rowID: WhatsAppCampaign.flyerRecordId,
        filename: name,
        path: path,
      );
      _save(_readForm().copyWithFile(pbName));
      setState(() => _uploadMsg = txt('save'));
    } catch (_) {
      setState(() => _uploadMsg = txt('errorHappenedWhen'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Expander(
        leading: const Icon(FluentIcons.send),
        header: Txt(txt('whatsappCampaign')),
        trailing: const AppliesToIndicator(scope: Scope.app),
        contentPadding: const EdgeInsets.all(10),
        content: SizedBox(
          width: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              InfoBar(
                title: Txt(txt('whatsappCampaignInfo')),
                severity: InfoBarSeverity.info,
              ),
              InfoLabel(
                label: txt('googleReviewUrl'),
                child: CupertinoTextField(
                  controller: reviewUrl,
                  placeholder: 'https://g.page/r/.../review',
                ),
              ),
              InfoLabel(
                label: txt('openrouterModel'),
                child: CupertinoTextField(
                  controller: model,
                  placeholder: 'openai/gpt-4o-mini',
                ),
              ),
              Checkbox(
                checked: campaign.sendFlyerWithChat,
                content: Txt(txt('sendFlyerWithChat')),
                onChanged: (v) {
                  campaign = _readForm();
                  _save(WhatsAppCampaign(
                    googleReviewUrl: campaign.googleReviewUrl,
                    sendFlyerWithChat: v ?? true,
                    flyerFile: campaign.flyerFile,
                    openrouterModel: campaign.openrouterModel,
                    birthdayTemplate: campaign.birthdayTemplate,
                    reviewTemplate: campaign.reviewTemplate,
                    marketingImageUrl: campaign.marketingImageUrl,
                    treatments: campaign.treatments,
                    quietStart: campaign.quietStart,
                    quietEnd: campaign.quietEnd,
                  ));
                },
              ),
              Text(txt('flyerHint'), style: FluentTheme.of(context).typography.caption),
              if (campaign.flyerFile.isNotEmpty)
                Text(campaign.flyerFile,
                    style: FluentTheme.of(context).typography.caption),
              if (_uploadMsg != null) Text(_uploadMsg!),
              Button(
                onPressed: login.isAdmin && network.isOnline() ? _pickFlyer : null,
                child: ButtonContent(FluentIcons.photo2_add, txt('uploadFlyer')),
              ),
              InfoLabel(
                label: txt('marketingImageUrl'),
                child: CupertinoTextField(
                  controller: marketingUrl,
                  placeholder: 'https://...',
                ),
              ),
              InfoLabel(
                label: txt('treatmentsNoPrices'),
                child: CupertinoTextField(controller: treatments, maxLines: 3),
              ),
              InfoLabel(
                label: txt('quietHours'),
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoTextField(
                        controller: quietStart,
                        placeholder: '21:00',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CupertinoTextField(
                        controller: quietEnd,
                        placeholder: '09:00',
                      ),
                    ),
                  ],
                ),
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

extension on WhatsAppCampaign {
  WhatsAppCampaign copyWithFile(String file) {
    return WhatsAppCampaign(
      googleReviewUrl: googleReviewUrl,
      sendFlyerWithChat: sendFlyerWithChat,
      flyerFile: file,
      openrouterModel: openrouterModel,
      birthdayTemplate: birthdayTemplate,
      reviewTemplate: reviewTemplate,
      marketingImageUrl: marketingImageUrl,
      treatments: treatments,
      quietStart: quietStart,
      quietEnd: quietEnd,
    );
  }
}
