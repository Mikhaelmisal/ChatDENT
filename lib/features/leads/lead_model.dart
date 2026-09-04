import 'package:chatdent/core/model.dart';
import 'package:chatdent/features/appointments/appointments_store.dart';
import 'package:chatdent/features/patients/patient_model.dart';
import 'package:chatdent/features/patients/patients_store.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:chatdent/services/login.dart';
import 'package:chatdent/utils/constants.dart';
import 'package:chatdent/utils/india_phone.dart';
import 'package:chatdent/utils/parsed_phone_number.dart';
import 'package:fluent_ui/fluent_ui.dart';

class LeadStage {
  static const newLead = 'new';
  static const contacted = 'contacted';
  static const interested = 'interested';
  static const scheduled = 'scheduled';
  static const reschedule = 'reschedule';
  static const converted = 'converted';
  static const lost = 'lost';

  static const List<String> all = [
    newLead,
    contacted,
    interested,
    scheduled,
    reschedule,
    converted,
    lost,
  ];

  static String labelKey(String stage) {
    switch (stage) {
      case contacted:
        return 'leadStageContacted';
      case interested:
        return 'leadStageInterested';
      case scheduled:
        return 'leadStageScheduled';
      case reschedule:
        return 'leadStageReschedule';
      case converted:
        return 'leadStageConverted';
      case lost:
        return 'leadStageLost';
      case newLead:
      default:
        return 'leadStageNew';
    }
  }

  static Color color(String stage) {
    switch (stage) {
      case contacted:
        return Colors.blue;
      case interested:
        return Colors.teal;
      case scheduled:
        return Colors.purple;
      case reschedule:
        return Colors.warningPrimaryColor;
      case converted:
        return Colors.successPrimaryColor;
      case lost:
        return Colors.grey;
      case newLead:
      default:
        return Colors.orange;
    }
  }
}

class LeadSource {
  static const facebook = 'facebook';
  static const instagram = 'instagram';
  static const google = 'google';
  static const walkIn = 'walkIn';
  static const manual = 'manual';
  static const other = 'other';

  static const List<String> all = [
    facebook,
    instagram,
    google,
    walkIn,
    manual,
    other,
  ];

  static String labelKey(String source) {
    if (all.contains(source)) return source;
    return 'other';
  }
}

class CallOutcome {
  static const none = '';
  static const noAnswer = 'noAnswer';
  static const wrongNumber = 'wrongNumber';
  static const callback = 'callback';
  static const booked = 'booked';
  static const notInterested = 'notInterested';

  static const List<String> all = [
    none,
    noAnswer,
    wrongNumber,
    callback,
    booked,
    notInterested,
  ];

  static String labelKey(String value) {
    switch (value) {
      case noAnswer:
        return 'callNoAnswer';
      case wrongNumber:
        return 'callWrongNumber';
      case callback:
        return 'callCallback';
      case booked:
        return 'callBooked';
      case notInterested:
        return 'callNotInterested';
      default:
        return 'callOutcome';
    }
  }

  static String label(String value) {
    if (value.isEmpty || !all.contains(value)) return txt('notSet');
    return txt(labelKey(value));
  }

  static Color color(String value) {
    switch (value) {
      case noAnswer:
        return Colors.orange;
      case wrongNumber:
        return Colors.grey;
      case callback:
        return Colors.blue;
      case booked:
        return Colors.successPrimaryColor;
      case notInterested:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class LeadTableLabel {
  final IconData icon;
  final Color? color;
  final String title;
  final String content;
  final double value;
  final String searchableString;
  final bool sortable;
  final bool view;
  final double? chipWidth;
  final double? titleWidth;

  LeadTableLabel({
    this.icon = FluentIcons.document,
    this.color,
    this.view = true,
    this.chipWidth,
    this.titleWidth,
    required this.title,
    required this.content,
    required this.value,
    required this.searchableString,
    required this.sortable,
  });
}

class Lead extends Model {
  @override
  bool get locked => login.perm(Perm.leads).not(2);

  Patient? get patient {
    if (patientID.isEmpty) return null;
    return patients.get(patientID);
  }

  String get phonesString =>
      phone.map((p) => '${p.countryCode}${p.nsn}').join('');

  String get stageLabel => txt(LeadStage.labelKey(stage));

  Color get stageColor => LeadStage.color(stage);

  String get sourceLabel {
    if (LeadSource.all.contains(source)) {
      return txt(LeadSource.labelKey(source));
    }
    return source.isEmpty ? txt('manual') : source;
  }

  bool get createdToday {
    final now = DateTime.now();
    return createdAt.year == now.year &&
        createdAt.month == now.month &&
        createdAt.day == now.day;
  }

  bool get needsCall =>
      !called &&
      stage != LeadStage.converted &&
      stage != LeadStage.lost;

  bool get canBookVisit =>
      called &&
      stage != LeadStage.lost &&
      callOutcome != CallOutcome.notInterested;

  bool get convertedWithoutVisit =>
      stage == LeadStage.converted &&
      (patient == null || patient!.doneAppointments.isEmpty);

  String get searchString {
    return [
      title,
      phonesString,
      email,
      source,
      campaign,
      interest,
      notes,
      stage,
      stageLabel,
      sourceLabel,
      coming ? 'coming' : '',
      callOutcome,
      CallOutcome.label(callOutcome),
    ].join(' ').toLowerCase();
  }

  String get phoneDisplay {
    if (phone.isEmpty) return txt('notSet');
    return phone.first.toInternationalFormat();
  }

  bool get isComing => coming || callOutcome == CallOutcome.booked;

  List<LeadTableLabel> get tableLabels {
    return [
      LeadTableLabel(
        title: txt('callOutcome'),
        content: CallOutcome.label(callOutcome),
        icon: FluentIcons.phone,
        color: CallOutcome.color(callOutcome),
        value: CallOutcome.all.indexOf(callOutcome).toDouble(),
        searchableString: CallOutcome.label(callOutcome),
        sortable: true,
        chipWidth: 140,
        titleWidth: 72,
      ),
      LeadTableLabel(
        title: txt('phone'),
        content: phoneDisplay,
        icon: WindowsIcons.phone,
        color: phone.isEmpty ? Colors.orange : null,
        value: 0,
        searchableString: phonesString,
        sortable: false,
        chipWidth: 168,
        titleWidth: 48,
      ),
      LeadTableLabel(
        title: txt('leadSource'),
        content: sourceLabel,
        icon: FluentIcons.flag,
        value: LeadSource.all.indexOf(source).toDouble(),
        searchableString: sourceLabel,
        sortable: true,
        chipWidth: 118,
        titleWidth: 52,
      ),
      LeadTableLabel(
        title: txt('interest'),
        content: interest.isEmpty ? txt('notSet') : interest,
        icon: FluentIcons.favorite_star,
        color: interest.isEmpty ? Colors.orange : null,
        value: interest.isEmpty ? 0 : 1,
        searchableString: interest,
        sortable: true,
        chipWidth: 118,
        titleWidth: 58,
      ),
      LeadTableLabel(
        title: txt('leadStage'),
        content: stageLabel,
        icon: FluentIcons.progress_ring_dots,
        color: stageColor,
        value: LeadStage.all.indexOf(stage).toDouble(),
        searchableString: stageLabel,
        sortable: true,
        chipWidth: 118,
        titleWidth: 48,
      ),
      LeadTableLabel(
        title: txt('email'),
        content: email.isEmpty ? txt('notSet') : email,
        icon: WindowsIcons.mail,
        color: email.isEmpty ? Colors.orange : null,
        value: 0,
        searchableString: email,
        sortable: false,
        chipWidth: 150,
        titleWidth: 42,
      ),
      LeadTableLabel(
        title: txt('leadCalled'),
        content: called ? '1' : '0',
        icon: FluentIcons.phone,
        value: called ? 1 : 0,
        searchableString: called ? 'called' : '',
        sortable: true,
        view: false,
      ),
      LeadTableLabel(
        title: txt('coming'),
        content: isComing ? '1' : '0',
        icon: FluentIcons.accept,
        value: isComing ? 1 : 0,
        searchableString: isComing ? 'coming' : '',
        sortable: true,
        view: false,
      ),
    ];
  }

  void markCalled(bool value) {
    called = value;
    if (!value) {
      coming = false;
      if (callOutcome == CallOutcome.booked) {
        callOutcome = CallOutcome.none;
      }
    } else if (stage == LeadStage.newLead) {
      stage = LeadStage.contacted;
      lastContactedAt = DateTime.now();
    }
  }

  void markComing(bool value) {
    coming = value;
    if (value) {
      called = true;
      callOutcome = CallOutcome.booked;
      lastContactedAt = DateTime.now();
      if (stage != LeadStage.converted && stage != LeadStage.lost) {
        stage = LeadStage.scheduled;
      }
    } else if (callOutcome == CallOutcome.booked) {
      callOutcome = CallOutcome.none;
    }
  }

  List<ParsedPhoneNumber> phone = [];
  String email = '';
  String source = LeadSource.manual;
  String campaign = '';
  String interest = '';
  String notes = '';
  String stage = LeadStage.newLead;
  String assignedTo = '';
  String patientID = '';
  String appointmentID = '';
  bool whatsappConsent = true;
  bool called = false;
  bool coming = false;
  bool marketingQueued = false;
  bool marketingSent = false;
  String marketingImageUrl = '';
  String marketingInstance = '';
  String marketingCaption = '';
  bool assistantPaused = false;
  String callOutcome = CallOutcome.none;
  String sendError = '';
  DateTime? lastContactedAt;
  DateTime? nextFollowUpAt;
  DateTime? lastAssistantAt;
  DateTime createdAt = DateTime.now();

  Lead.fromJson(super.json) : super.fromJson();

  @override
  Lead copy(bool blank) {
    return Lead.fromJson(blank ? {} : toJson());
  }

  static List<ParsedPhoneNumber> phonesFromStored(dynamic raw) {
    if (raw == null) return [];
    final text = raw.toString().trim();
    if (text.isEmpty) return [];
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (RegExp(r'^91\d{10}$').hasMatch(digits)) {
      try {
        return [ParsedPhoneNumber(IndiaPhone.e164(digits.substring(2)))];
      } catch (_) {
        return [];
      }
    }
    final local = IndiaPhone.localDigitsFrom(text);
    if (IndiaPhone.isCompleteLocal(local)) {
      try {
        return [ParsedPhoneNumber(IndiaPhone.e164(local))];
      } catch (_) {
        return [];
      }
    }
    if (digits.length >= 11) {
      try {
        return [ParsedPhoneNumber('+$digits')];
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  static DateTime? _dateFromJson(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    final n = int.tryParse(raw.toString());
    if (n == null || n == 0) return null;
    if (n > 9999999999) {
      return DateTime.fromMillisecondsSinceEpoch(n);
    }
    return DateTime.fromMillisecondsSinceEpoch(n * 1000);
  }

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    phone = phonesFromStored(json['phone']);
    email = json['email'] ?? email;
    source = json['source'] ?? source;
    campaign = json['campaign'] ?? campaign;
    interest = json['interest'] ?? interest;
    notes = json['notes'] ?? notes;
    stage = json['stage'] ?? stage;
    assignedTo = json['assignedTo'] ?? assignedTo;
    patientID = json['patientID'] ?? patientID;
    appointmentID = json['appointmentID'] ?? appointmentID;
    whatsappConsent = json['whatsappConsent'] ?? whatsappConsent;
    called = json['called'] ?? called;
    coming = json['coming'] ?? coming;
    marketingQueued = json['marketingQueued'] ?? marketingQueued;
    marketingSent = json['marketingSent'] ?? marketingSent;
    marketingImageUrl = json['marketingImageUrl'] ?? marketingImageUrl;
    marketingInstance = json['marketingInstance'] ?? marketingInstance;
    marketingCaption = json['marketingCaption'] ?? marketingCaption;
    assistantPaused = json['assistantPaused'] ?? assistantPaused;
    callOutcome = json['callOutcome'] ?? callOutcome;
    sendError = json['sendError'] ?? sendError;
    lastContactedAt = _dateFromJson(json['lastContactedAt']) ?? lastContactedAt;
    nextFollowUpAt = _dateFromJson(json['nextFollowUpAt']) ?? nextFollowUpAt;
    lastAssistantAt = _dateFromJson(json['lastAssistantAt']) ?? lastAssistantAt;
    createdAt = _dateFromJson(json['createdAt']) ??
        lastContactedAt ??
        lastAssistantAt ??
        (json['id'] == null
            ? DateTime.now()
            : DateTime.fromMillisecondsSinceEpoch(0));
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    final d = Lead.fromJson({});
    if (phone != d.phone) json['phone'] = phonesString;
    if (email != d.email) json['email'] = email;
    if (source != d.source) json['source'] = source;
    if (campaign != d.campaign) json['campaign'] = campaign;
    if (interest != d.interest) json['interest'] = interest;
    if (notes != d.notes) json['notes'] = notes;
    if (stage != d.stage) json['stage'] = stage;
    if (assignedTo != d.assignedTo) json['assignedTo'] = assignedTo;
    if (patientID != d.patientID) json['patientID'] = patientID;
    if (appointmentID != d.appointmentID) json['appointmentID'] = appointmentID;
    if (whatsappConsent != d.whatsappConsent) {
      json['whatsappConsent'] = whatsappConsent;
    }
    if (called != d.called) json['called'] = called;
    if (coming != d.coming) json['coming'] = coming;
    if (marketingQueued != d.marketingQueued) {
      json['marketingQueued'] = marketingQueued;
    }
    if (marketingSent != d.marketingSent) json['marketingSent'] = marketingSent;
    if (marketingImageUrl != d.marketingImageUrl) {
      json['marketingImageUrl'] = marketingImageUrl;
    }
    if (marketingInstance != d.marketingInstance) {
      json['marketingInstance'] = marketingInstance;
    }
    if (marketingCaption != d.marketingCaption) {
      json['marketingCaption'] = marketingCaption;
    }
    if (assistantPaused != d.assistantPaused) {
      json['assistantPaused'] = assistantPaused;
    }
    if (callOutcome != d.callOutcome) json['callOutcome'] = callOutcome;
    if (sendError != d.sendError) json['sendError'] = sendError;
    if (lastContactedAt != null) {
      json['lastContactedAt'] = lastContactedAt!.millisecondsSinceEpoch;
    }
    if (nextFollowUpAt != null) {
      json['nextFollowUpAt'] = nextFollowUpAt!.millisecondsSinceEpoch;
    }
    if (lastAssistantAt != null) {
      json['lastAssistantAt'] = lastAssistantAt!.millisecondsSinceEpoch;
    }
    json['createdAt'] = createdAt.millisecondsSinceEpoch;
    return json;
  }

  bool get hasUpcomingAppointment {
    if (appointmentID.isEmpty) return false;
    final apt = appointments.get(appointmentID);
    return apt != null && apt.archived != true;
  }
}
