import 'dart:convert';

import 'package:chatdent/features/leads/clinic_hours.dart';
import 'package:chatdent/features/notes/notes_store.dart';
import 'package:chatdent/features/settings/settings_model.dart';
import 'package:chatdent/features/settings/settings_stores.dart';
import 'package:chatdent/utils/uuid.dart';

/// PocketBase-safe 15-char ids for canned WhatsApp messages (Settings JSON).
class WhatsAppTemplateIds {
  static const settingId = 'wa_templates___';
  static const legacyColumn = 'wa_msg_column__';
  static const welcome = 'wa_welcome_____';
  static const confirm = 'wa_confirm_____';
  static const history = 'wa_history_____';
  static const aftercare = 'wa_aftercare___';
  static const remind = 'wa_remind______';
  static const birthday = 'wa_birthday____';
  static const review = 'wa_review______';
  static const alertNew = 'wa_alert_new___';
  static const alertBack = 'wa_alert_back__';
  static const optOut = 'wa_optout______';

  static const allIds = [
    welcome,
    confirm,
    history,
    aftercare,
    remind,
    birthday,
    review,
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
Namaste {name},

Welcome to {clinic}.

To help us prepare for your visit, please reply with:
• Your full name
• The dental concern (tooth pain, cleaning, braces, implant, gum, kids, or other)

A doctor or receptionist will call you to confirm the appointment. We do not share fees on WhatsApp — the doctor will discuss this with you in person or on the call.

Important contacts:
📞 Appointments: {phone}

📍 Clinic
{address}

{maps}

We look forward to taking care of your smile.

{clinic} Team
''';

const _confirmBody = '''
Namaste {name},

Your visit at {clinic} is confirmed.

📅 Date: {date}
🗓️ Day: {day}
🕒 Time: {time}

📍 Location:
{address}

{maps}

Before your visit, kindly bring:
* Previous prescriptions
* Current medicines you are taking
* X-rays or scans (if you have them)
* Previous dental treatment records, if available

Please arrive 10–15 minutes before your appointment.

For any assistance, contact:
{phone}

{clinic} Team
''';

const _historyBody = '''
Namaste {name},

Before your consultation at {clinic}, please keep the following ready so the doctor can help you properly:

• Any medical conditions (diabetes, BP, heart, thyroid, allergies)
• Medicines you take every day
• If you are pregnant or breastfeeding
• Previous dental work (root canal, braces, implants, extractions)

You can reply here in a short list, or we will take this history when the doctor calls.

We never quote treatment fees on WhatsApp.

📞 {phone}
📍 {address}

{clinic} Team
''';

const _aftercareBody = '''
Namaste {name},

Thank you for visiting {clinic}.

If you had a procedure today:
• Bite on the gauze as instructed
• Avoid hot drinks and rinsing for a few hours if you had an extraction
• Take medicines only as the doctor prescribed
• Call us if pain or swelling increases

If you were happy with your care, we would be grateful for a Google review when you have a moment.

For questions, call {phone}. The doctor will advise on fees or further treatment only on a call or in the clinic.

{clinic} Team
''';

const _remindBody = '''
Namaste {name},

Reminder: you have an appointment at {clinic}.

📅 Date: {date}
🗓️ Day: {day}
🕒 Time: {time}

📍 Location:
{address}

{maps}

Please arrive 10–15 minutes before your appointment. Reply RESCHEDULE if you need a different time and our team will call you.

For any assistance, contact:
{phone}

{clinic} Team
''';

const _birthdayBody = '''
Namaste {name},

Happy birthday from everyone at {clinic}! We wish you a wonderful year and a healthy smile.

We would love to see you when it is convenient. A doctor will discuss any treatment in person or on a call — we do not share fees on WhatsApp.

📞 {phone}
📍 {address}

{clinic} Team
''';

const _reviewBody = '''
Namaste {name},

Thank you for visiting {clinic}. If you were happy with your care, please leave us a Google review:

{reviewUrl}

For any assistance, contact:
{phone}

{clinic} Team
''';

const _alertNewBody = '''
🆕 New WhatsApp lead

Phone: {phone}
Name: {name}
Note: {note}

Please call from the clinic number. Do not reply in this group.
''';

const _alertBackBody = '''
🔁 Returning patient

Phone: {phone}
Name: {name}
Note: {note}

Please call from the clinic number. Do not reply in this group.
''';

const _optOutBody = '''
Namaste {name},

You have been unsubscribed from {clinic} WhatsApp messages. We will not send further campaigns.

For appointments you can still call {phone}.

{clinic} Team
''';

String fillWhatsAppTemplate(
  String raw, {
  String name = '',
  String date = '',
  String day = '',
  String time = '',
  String note = '',
  String reviewUrl = '',
}) {
  final evo = EvolutionSettings.fromJsonString(
    globalSettings.evolutionSettingsJson,
  );
  final clinic = evo.clinicName.trim().isEmpty ? 'Smile Dental Care' : evo.clinicName.trim();
  final phone = globalSettings.phone.trim().isEmpty
      ? '+91 86001 06020'
      : globalSettings.phone.trim();
  final address = evo.clinicAddress.trim().isEmpty
      ? 'Please see the Google Maps link below.'
      : evo.clinicAddress.trim();
  final maps = evo.googleMapsUrl.trim();
  return raw
      .replaceAll('{name}', name.trim().isEmpty ? 'ji' : name.trim())
      .replaceAll('{clinic}', clinic)
      .replaceAll('{phone}', phone)
      .replaceAll('{address}', address)
      .replaceAll('{maps}', maps)
      .replaceAll('{date}', date)
      .replaceAll('{day}', day)
      .replaceAll('{time}', time)
      .replaceAll('{note}', note)
      .replaceAll('{reviewUrl}', reviewUrl)
      .trim();
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

void ensureWhatsAppTemplates() {
  final raw = globalSettings.get(WhatsAppTemplateIds.settingId).value;
  var templates = WhatsAppTemplates.fromJsonString(raw);
  var changed = raw.trim().isEmpty;

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
      WhatsAppTemplateIds.history: _historyBody.trim(),
      WhatsAppTemplateIds.aftercare: _aftercareBody.trim(),
      WhatsAppTemplateIds.remind: _remindBody.trim(),
      WhatsAppTemplateIds.birthday: _birthdayBody.trim(),
      WhatsAppTemplateIds.review: _reviewBody.trim(),
      WhatsAppTemplateIds.alertNew: _alertNewBody.trim(),
      WhatsAppTemplateIds.alertBack: _alertBackBody.trim(),
      WhatsAppTemplateIds.optOut: _optOutBody.trim(),
    };
