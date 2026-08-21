import 'dart:convert';

import 'package:chatdent/features/leads/clinic_hours.dart';
import 'package:chatdent/features/notes/notes_store.dart';
import 'package:chatdent/features/settings/settings_model.dart';
import 'package:chatdent/features/settings/settings_stores.dart';
import 'package:chatdent/utils/uuid.dart';

/// PocketBase-safe 15-char ids for canned WhatsApp messages (Settings JSON).
class WhatsAppTemplateIds {
  static const settingId = 'wa_templates___';
  static const versionId = 'wa_tpl_ver_____';
  static const legacyColumn = 'wa_msg_column__';
  static const welcome = 'wa_welcome_____';
  static const confirm = 'wa_confirm_____';
  static const welcomeConfirm = 'wa_welconfirm__';
  static const history = 'wa_history_____';
  static const aftercare = 'wa_aftercare___';
  static const remind = 'wa_remind______';
  static const birthday = 'wa_birthday____';
  static const review = 'wa_review______';
  static const noShow = 'wa_noshow______';
  static const reschedule = 'wa_reschedule__';
  static const prescription = 'wa_rx__________';
  static const leave = 'wa_leave________';
  static const nextBrief = 'wa_next_brief___';
  static const alertNew = 'wa_alert_new___';
  static const alertBack = 'wa_alert_back__';
  static const optOut = 'wa_optout______';

  /// Bump to force-refresh saved defaults after copy improvements.
  static const templatesVersion = 4;

  static const allIds = [
    welcome,
    confirm,
    welcomeConfirm,
    history,
    aftercare,
    remind,
    birthday,
    review,
    noShow,
    reschedule,
    prescription,
    leave,
    nextBrief,
    alertNew,
    alertBack,
    optOut,
  ];
}

class WhatsAppCampaignMsg {
  final String id;
  final String title;
  final String body;

  const WhatsAppCampaignMsg({
    required this.id,
    required this.title,
    required this.body,
  });

  factory WhatsAppCampaignMsg.fromJson(Map<String, dynamic> json) {
    return WhatsAppCampaignMsg(
      id: json['id']?.toString() ?? uuid(),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
      };
}

class WhatsAppTemplates {
  final Map<String, String> bodies;
  final List<WhatsAppCampaignMsg> campaigns;

  const WhatsAppTemplates({
    required this.bodies,
    this.campaigns = const [],
  });

  factory WhatsAppTemplates.defaults() {
    return WhatsAppTemplates(bodies: Map<String, String>.from(_defaultBodies));
  }

  factory WhatsAppTemplates.fromJsonString(String raw) {
    if (raw.trim().isEmpty) return WhatsAppTemplates.defaults();
    try {
      return WhatsAppTemplates.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return WhatsAppTemplates.defaults();
    }
  }

  factory WhatsAppTemplates.fromJson(Map<String, dynamic> json) {
    final bodies = <String, String>{};
    for (final id in WhatsAppTemplateIds.allIds) {
      final v = json[id]?.toString().trim();
      bodies[id] = (v != null && v.isNotEmpty) ? v : (_defaultBodies[id] ?? '');
    }
    final campaigns = <WhatsAppCampaignMsg>[];
    final rawList = json['campaigns'];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          campaigns.add(WhatsAppCampaignMsg.fromJson(item));
        } else if (item is Map) {
          campaigns.add(WhatsAppCampaignMsg.fromJson(
              Map<String, dynamic>.from(item)));
        }
      }
    }
    return WhatsAppTemplates(bodies: bodies, campaigns: campaigns);
  }

  String bodyOf(String id) => (bodies[id] ?? '').trim();

  WhatsAppTemplates withBody(String id, String body) {
    return WhatsAppTemplates(
      bodies: {...bodies, id: body.trim()},
      campaigns: campaigns,
    );
  }

  WhatsAppTemplates withCampaigns(List<WhatsAppCampaignMsg> next) {
    return WhatsAppTemplates(bodies: bodies, campaigns: next);
  }

  Map<String, dynamic> toJson() => {
        ...bodies,
        'campaigns': campaigns.map((e) => e.toJson()).toList(),
      };

  String toJsonString() => jsonEncode(toJson());
}

const _welcomeBody = '''
Hi {name},

Welcome to {clinic}!

To help us prepare for your visit, please reply with:
1) Your full name
2) Your dental concern (pain, cleaning, braces, implant, gum, kids, or other)

A doctor or receptionist will call you to confirm your appointment.

Appointments: {phone}

We look forward to taking care of your smile.

- Team {clinic}
''';

const _confirmBody = '''
Hi {name},

Your visit at {clinic} is confirmed.

Date: {date}
Day: {day}
Time: {time}

Please arrive 10-15 minutes early.

Need help? Call {phone}

- Team {clinic}
''';

const _welcomeConfirmBody = '''
Hi {name},

Welcome to {clinic} - your visit is confirmed!

Date: {date}
Day: {day}
Time: {time}

Please arrive 10-15 minutes early.

Need help? Call {phone}

- Team {clinic}
''';

const _historyBody = '''
Hi {name},

Before your consultation at {clinic}, please share a short list (or we can take it on the call):

- Medical conditions (diabetes, BP, heart, thyroid, allergies)
- Daily medicines
- Pregnancy / breastfeeding (if applicable)
- Previous dental work (RCT, braces, implants, extractions)

{phone}

- Team {clinic}
''';

const _aftercareBody = '''
Hi {name},

Thank you for visiting {clinic} today. We are glad we could take care of you.

Please follow the doctor's advice and call us if pain or swelling increases.

We hope you feel better soon.

{phone}

- Team {clinic}
''';

const _remindBody = '''
Hi {name},

This is a gentle reminder for your appointment at {clinic} tomorrow.

Date: {date}
Day: {day}
Time: {time}

Please arrive 10-15 minutes early.
Reply RESCHEDULE if you need a different time - our team will call you.

{phone}

- Team {clinic}
''';

const _birthdayBody = '''
Hi {name},

Happy birthday from everyone at {clinic}!

We wish you a wonderful year and a healthy smile.
We would love to see you when it is convenient.

{phone}

- Team {clinic}
''';

const _reviewBody = '''
Hi {name},

Thank you for visiting {clinic}.

If you were happy with your care, your Google review means a lot to our team.

Please tap the link below to leave a review:

{reviewUrl}

After you submit it, reply here with DONE - we will note it on your record.

Thank you again for trusting us with your smile.

- Team {clinic}
''';

const _noShowBody = '''
Hi {name},

We missed you at {clinic} for your visit on {date} at {time}.

Reply here or call {phone} and we will help you book a new time.

- Team {clinic}
''';

const _rescheduleBody = '''
Hi {name},

Your visit at {clinic} has been updated.

Date: {date}
Day: {day}
Time: {time}

Please arrive 10-15 minutes early.

Need help? Call {phone}

- Team {clinic}
''';

const _prescriptionBody = '''
Hi {name},

Thank you for visiting {clinic}. Here is your prescription:

{note}

Please take the medicines exactly as advised.

We hope you feel better soon.

{phone}

- Team {clinic}
''';

const _leaveBody = '''
Hi {name},

Welcome - thank you for visiting {clinic} today.

{note}We hope you feel better soon. Please follow the doctor's advice and call us if anything worries you.

{phone}

- Team {clinic}
''';

const _nextBriefBody = '''
Hi {name},

Your next visit at {clinic}:

Date: {date}
Time: {time}

See you then.

- Team {clinic}
''';

const _alertNewBody = '''
New WhatsApp lead

Phone: {phone}
Name: {name}
Note: {note}

Please call from the clinic number. Do not reply in this group.
''';

const _alertBackBody = '''
Returning patient

Phone: {phone}
Name: {name}
Note: {note}

Please call from the clinic number. Do not reply in this group.
''';

const _optOutBody = '''
Hi {name},

You have been unsubscribed from {clinic} WhatsApp messages. We will not send further campaigns.

For appointments you can still call {phone}.

- Team {clinic}
''';


String sanitizeWhatsAppText(String raw) {
  return raw
      .replaceAll('\u2014', '-')
      .replaceAll('\u2013', '-')
      .replaceAll('\u2022', '-')
      .replaceAll('\u2018', "'")
      .replaceAll('\u2019', "'")
      .replaceAll('\u201c', '"')
      .replaceAll('\u201d', '"')
      .replaceAll('\u00a0', ' ')
      .trim();
}

String fillWhatsAppTemplate(
  String raw, {
  String name = '',
  String date = '',
  String day = '',
  String time = '',
  String note = '',
  String reviewUrl = '',
  bool includeMaps = false,
}) {
  final evo = EvolutionSettings.fromJsonString(
    globalSettings.evolutionSettingsJson,
  );
  final clinicRaw = evo.clinicName.trim().isEmpty
      ? 'Smile Dental Care'
      : evo.clinicName.trim();
  // WhatsApp markdown bold so clinic branding always stands out.
  final clinic = clinicRaw.contains('*') ? clinicRaw : '*$clinicRaw*';
  final phone = globalSettings.phone.trim().isEmpty
      ? '+91 86001 06020'
      : globalSettings.phone.trim();
  final address = evo.clinicAddress.trim().isEmpty
      ? 'Please ask the clinic for directions.'
      : evo.clinicAddress.trim();
  // Empty maps avoids Google Maps link-preview cards in WhatsApp.
  final maps = includeMaps ? evo.googleMapsUrl.trim() : '';
  return sanitizeWhatsAppText(
    raw
        .replaceAll('{name}', name.trim().isEmpty ? 'ji' : name.trim())
        .replaceAll('{clinic}', clinic)
        .replaceAll('{phone}', phone)
        .replaceAll('{address}', address)
        .replaceAll('{maps}', maps)
        .replaceAll('{date}', date)
        .replaceAll('{day}', day)
        .replaceAll('{time}', time)
        .replaceAll('{note}', note.trim())
        .replaceAll('{reviewUrl}', reviewUrl),
  );
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _weekdays = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

/// Fills a saved Settings template. Empty body returns ''.
String filledWhatsAppNote(
  String id, {
  String name = '',
  DateTime? when,
  String note = '',
  String reviewUrl = '',
}) {
  ensureWhatsAppTemplates();
  final body = loadWhatsAppTemplates().bodyOf(id);
  if (body.isEmpty) return '';
  var date = '';
  var day = '';
  var time = '';
  if (when != null) {
    final local = when.toLocal();
    date =
        '${local.day.toString().padLeft(2, '0')}-${_months[local.month - 1]}-${local.year}';
    day = _weekdays[local.weekday % 7];
    time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
  return fillWhatsAppTemplate(
    body,
    name: name,
    date: date,
    day: day,
    time: time,
    note: note,
    reviewUrl: reviewUrl,
  );
}

WhatsAppTemplates loadWhatsAppTemplates() {
  return WhatsAppTemplates.fromJsonString(
    globalSettings.get(WhatsAppTemplateIds.settingId).value,
  );
}

void persistWhatsAppTemplates(WhatsAppTemplates templates) {
  globalSettings.set(Setting.fromJson({
    'id': WhatsAppTemplateIds.settingId,
    'value': templates.toJsonString(),
  }));
}

void resetWhatsAppTemplatesToDefaults() {
  final campaigns = loadWhatsAppTemplates().campaigns;
  persistWhatsAppTemplates(
    WhatsAppTemplates.defaults().withCampaigns(campaigns),
  );
  globalSettings.set(Setting.fromJson({
    'id': WhatsAppTemplateIds.versionId,
    'value': '${WhatsAppTemplateIds.templatesVersion}',
  }));
}

void ensureWhatsAppTemplates() {
  final raw = globalSettings.get(WhatsAppTemplateIds.settingId).value;
  var templates = WhatsAppTemplates.fromJsonString(raw);
  var changed = raw.trim().isEmpty;

  final ver = int.tryParse(
          globalSettings.get(WhatsAppTemplateIds.versionId).value.trim()) ??
      0;
  if (ver < WhatsAppTemplateIds.templatesVersion) {
    // Keep custom campaign drafts; refresh official canned copy.
    templates = WhatsAppTemplates.defaults().withCampaigns(templates.campaigns);
    changed = true;
    globalSettings.set(Setting.fromJson({
      'id': WhatsAppTemplateIds.versionId,
      'value': '${WhatsAppTemplateIds.templatesVersion}',
    }));
  }

  for (final id in WhatsAppTemplateIds.allIds) {
    final n = notes.get(id);
    if (n == null || n.archived == true) continue;
    final fromNote = n.note.trim();
    if (fromNote.isEmpty) continue;
    if (raw.trim().isEmpty || templates.bodyOf(id) == _defaultBodies[id]) {
      templates = templates.withBody(id, fromNote);
      changed = true;
    }
  }

  final extra = notes.present.values.where((n) =>
      n.isNote &&
      n.columnID == WhatsAppTemplateIds.legacyColumn &&
      !WhatsAppTemplateIds.allIds.contains(n.id));
  if (extra.isNotEmpty) {
    final campaigns = [...templates.campaigns];
    for (final n in extra) {
      if (campaigns.any((c) => c.id == n.id)) continue;
      campaigns.add(WhatsAppCampaignMsg(
        id: n.id,
        title: n.title,
        body: n.note,
      ));
      changed = true;
    }
    templates = templates.withCampaigns(campaigns);
  }

  if (changed) persistWhatsAppTemplates(templates);

  for (final id in [
    ...WhatsAppTemplateIds.allIds,
    WhatsAppTemplateIds.legacyColumn,
  ]) {
    final n = notes.get(id);
    if (n != null && n.archived != true) notes.archive(id);
  }
  for (final n in notes.present.values
      .where((x) => x.columnID == WhatsAppTemplateIds.legacyColumn)
      .toList()) {
    notes.archive(n.id);
  }
}

Map<String, String> get _defaultBodies => {
      WhatsAppTemplateIds.welcome: _welcomeBody.trim(),
      WhatsAppTemplateIds.confirm: _confirmBody.trim(),
      WhatsAppTemplateIds.welcomeConfirm: _welcomeConfirmBody.trim(),
      WhatsAppTemplateIds.history: _historyBody.trim(),
      WhatsAppTemplateIds.aftercare: _aftercareBody.trim(),
      WhatsAppTemplateIds.remind: _remindBody.trim(),
      WhatsAppTemplateIds.birthday: _birthdayBody.trim(),
      WhatsAppTemplateIds.review: _reviewBody.trim(),
      WhatsAppTemplateIds.noShow: _noShowBody.trim(),
      WhatsAppTemplateIds.reschedule: _rescheduleBody.trim(),
      WhatsAppTemplateIds.prescription: _prescriptionBody.trim(),
      WhatsAppTemplateIds.leave: _leaveBody.trim(),
      WhatsAppTemplateIds.nextBrief: _nextBriefBody.trim(),
      WhatsAppTemplateIds.alertNew: _alertNewBody.trim(),
      WhatsAppTemplateIds.alertBack: _alertBackBody.trim(),
      WhatsAppTemplateIds.optOut: _optOutBody.trim(),
    };
