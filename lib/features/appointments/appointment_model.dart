import 'package:chatdent/core/model.dart';
import 'package:chatdent/features/accounts/accounts_controller.dart';
import 'package:chatdent/services/launch.dart';
import 'package:chatdent/features/appointments/procedure_protocols.dart';
import 'package:chatdent/features/patients/patient_model.dart';
import 'package:chatdent/features/patients/patients_store.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:chatdent/services/login.dart';
import 'package:chatdent/utils/constants.dart';
import 'package:chatdent/utils/imgs.dart';

class Appointment extends Model {
  @override
  String? get avatar {
    if (launch.isDemo) return demoPersonAvatarUrl;
    if (imgs.isEmpty) return null;
    return imgs.first;
  }

  @override
  String get title {
    if (patient == null) {
      return "  ";
    } else if (patient!.title.isEmpty) {
      return "  ";
    } else {
      return patient!.title;
    }
  }

  @override
  bool get locked {
    // lock if only personal appointments are permissible
    // and the appointment doesn't have the current account id as an operator
    if (login.perm(Perm.appointments).exact(2)) {
      return false;
    } else if (login.perm(Perm.appointments).exact(1)) {
      if (operatorsIDs.contains(login.currentAccountID)) {
        return false;
      } else {
        return true;
      }
    } else {
      return true;
    }
  }

  Patient? get patient {
    return patients.get(patientID ?? "return null when null");
  }

  String get subtitleLine1 {
    return "${isDone ? "✔️ " : ""}${isDone && postOpNotes.isNotEmpty ? postOpNotes : preOpNotes}";
  }

  String get subtitleLine2 {
    return operatorsNames;
  }

  String get operatorsNames {
    if (operatorsIDs.isEmpty) return "";
    return operatorsIDs.map((id) => accounts.nameOrEmailFromID(id)).join(", ");
  }

  bool get userIsOperator {
    return operatorsIDs.contains(login.currentAccountID);
  }

  bool get fullPaid {
    return paid == price;
  }

  bool get overPaid {
    return paid > price;
  }

  bool get underPaid {
    return paid < price;
  }

  double get paymentDifference {
    return (paid - price).abs();
  }

  /// Paid minus billed through this visit (earlier visits included).
  /// Positive = overpaid, negative = still due.
  double get runningBalanceThroughThisVisit {
    final all = patient?.allAppointments ?? const <Appointment>[];
    final through = <Appointment>[];
    var found = false;
    for (final a in all) {
      through.add(a);
      if (a.id == id) {
        found = true;
        break;
      }
    }
    if (!found) {
      through.add(this);
    }
    return Patient.runningBalanceOf(through);
  }

  bool get isMissed {
    return date.isBefore(DateTime.now()) &&
        date.difference(DateTime.now()).inDays.abs() > 0 &&
        !isDone &&
        !isNoShow;
  }

  DateTime get endDate => date.add(Duration(minutes: duration));

  bool get firstAppointmentForThisPatient {
    if (patient == null) return false;
    if (patient!.allAppointments.isEmpty) return false;
    return patient!.allAppointments.first == this;
  }

  bool get isLaboworkUndelivered {
    if (!hasLabwork || !labworkReceived) return false;
    if (patient == null || patient!.allAppointments.isEmpty) return true;
    return patient!.allAppointments.last.id == id;
  }

  String get labworkStatus {
    if (!hasLabwork) return "none";
    if (!labworkReceived) return txt("waitingForLab");
    if (isLaboworkUndelivered) return txt("undelivered");
    return txt("receivedAndDelivered");
  }

  List<String> get viewableImgs {
    return imgs.where((name) => isAnImageName(name)).toList();
  }

  /// DCM X-ray filenames attached to this appointment, filtered to valid
  /// `.dcm`/`.dicom` names. Guards against stale or corrupt entries.
  List<String> get viewableDcmImgs {
    return dcmImgs.where(isADcmName).toList();
  }

  // id: id of the appointment (inherited from Model)

  /* 1 */ List<String> operatorsIDs = [];
  /* 2 */ String? patientID;
  /* 3 */ String preOpNotes = "";
  /* 4 */ String postOpNotes = "";
  /* 5 */ List<String> prescriptions = [];
  /* 6 */ double price = 0;
  /* 7 */ double paid = 0;
  /* 8 */ List<String> imgs = [];
  /* 9 */ DateTime date = DateTime.now();
  /* 10 */ bool isDone = false;
  /* 11 */ Map<String, String> teeth = {};
  /* 11b */ Map<String, String> teethExtraNotes = {};
  /* 11c */ Map<String, ToothProcedureProgress> procedureProgress = {};
  /* 12 */ bool hasLabwork = false;
  /* 13 */ String labName = "";
  /* 14 */ String labworkNotes = "";
  /* 15 */ bool labworkReceived = false;
  /* 16 */ Map<String, String> drawings = {};
  /* 17 */ int duration = 20; // minutes; 3 visits per hour
  /* 18 */ List<String> dcmImgs = []; // DICOM X-ray filenames
  /* 19 */ bool reminder24Sent = false;
  /* 20 */ bool reminder2Sent = false;
  /* 21 */ bool rescheduleRequested = false;
  /* 22 */ bool isNoShow = false;
  /* 23 */ bool confirmWhatsAppSent = false;
  /* 24 */ bool noShowWhatsAppSent = false;
  /* 25 */ bool aftercareWhatsAppSent = false;
  /* 26 */ String? treatmentPlanId;
  /* 27 */ int? briefConfirmDueMs;
  /* 28 */ bool briefConfirmSent = false;

  Appointment.fromJson(super.json) : super.fromJson();

  @override
  Appointment copy(bool blank) {
    return Appointment.fromJson(blank ? {} : toJson());
  }

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    /* 1 */ operatorsIDs =
        List<String>.from(json["operatorsIDs"] ?? operatorsIDs);
    /* 2 */ prescriptions =
        List<String>.from(json["prescriptions"] ?? prescriptions);
    /* 3 */ patientID = json["patientID"] ?? patientID;
    /* 4 */ preOpNotes = json["preOpNotes"] ?? preOpNotes;
    /* 5 */ postOpNotes = json["postOpNotes"] ?? postOpNotes;
    /* 6 */ price = double.parse((json["price"] ?? price).toString());
    /* 7 */ paid = double.parse((json["paid"] ?? paid).toString());
    /* 8 */ imgs = List<String>.from(json["imgs"] ?? imgs);
    /* 9 */ date = (json["date"] != null
        ? DateTime.fromMillisecondsSinceEpoch((json["date"] * 60000).toInt())
        : date);
    /* 10 */ isDone = (json["isDone"] ?? isDone);
    /* 11 */ teeth = Map<String, String>.from(json['teeth'] ?? teeth);
    /* 11b */ teethExtraNotes =
        Map<String, String>.from(json['teethExtraNotes'] ?? teethExtraNotes);
    /* 11c */ procedureProgress = {};
    final rawProgress = json['procedureProgress'];
    if (rawProgress is Map) {
      rawProgress.forEach((key, value) {
        if (value is Map) {
          procedureProgress[key.toString()] = ToothProcedureProgress.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      });
    }
    /* 12 */ hasLabwork = json["hasLabwork"] ?? hasLabwork;
    /* 13 */ labName = json["labName"] ?? labName;
    /* 14 */ labworkNotes = json["labworkNotes"] ?? labworkNotes;
    /* 15 */ labworkReceived = json["labworkReceived"] ?? labworkReceived;
    /* 16 */ drawings = Map<String, String>.from(json['drawings'] ?? drawings);
    /* 17 */ duration = (json["duration"] as int?) ?? duration;
    /* 18 */ dcmImgs = List<String>.from(json["dcmImgs"] ?? dcmImgs);
    /* 19 */ reminder24Sent = json["reminder24Sent"] ?? reminder24Sent;
    /* 20 */ reminder2Sent = json["reminder2Sent"] ?? reminder2Sent;
    /* 21 */ rescheduleRequested =
        json["rescheduleRequested"] ?? rescheduleRequested;
    /* 22 */ isNoShow = json["isNoShow"] ?? isNoShow;
    /* 23 */ confirmWhatsAppSent =
        json["confirmWhatsAppSent"] ?? confirmWhatsAppSent;
    /* 24 */ noShowWhatsAppSent =
        json["noShowWhatsAppSent"] ?? noShowWhatsAppSent;
    /* 25 */ aftercareWhatsAppSent =
        json["aftercareWhatsAppSent"] ?? aftercareWhatsAppSent;
    /* 26 */ treatmentPlanId =
        json["treatmentPlanId"]?.toString() ?? treatmentPlanId;
    /* 27 */ briefConfirmDueMs = json["briefConfirmDueMs"] is num
        ? (json["briefConfirmDueMs"] as num).toInt()
        : briefConfirmDueMs;
    /* 28 */ briefConfirmSent = json["briefConfirmSent"] ?? briefConfirmSent;
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    final d = Appointment.fromJson({});
    /* 1 */ if (operatorsIDs.isNotEmpty) json['operatorsIDs'] = operatorsIDs;
    /* 2 */ if (prescriptions.isNotEmpty) json['prescriptions'] = prescriptions;
    /* 3 */ if (patientID != d.patientID) json['patientID'] = patientID;
    /* 4 */ if (preOpNotes != d.preOpNotes) json['preOpNotes'] = preOpNotes;
    /* 5 */ if (postOpNotes != d.postOpNotes) json['postOpNotes'] = postOpNotes;
    /* 6 */ if (price != d.price) json['price'] = price;
    /* 7 */ if (paid != d.paid) json['paid'] = paid;
    /* 8 */ if (imgs.isNotEmpty) json['imgs'] = imgs;
    /* 9 */ if (isDone != d.isDone) json['isDone'] = isDone;
    /* 10 */ json['date'] = (date.millisecondsSinceEpoch / 60000).round();
    /* 11 */ if (teeth.isNotEmpty) json['teeth'] = teeth;
    /* 11b */ if (teethExtraNotes.isNotEmpty)
      json['teethExtraNotes'] = teethExtraNotes;
    /* 11c */ if (procedureProgress.isNotEmpty) {
      json['procedureProgress'] = {
        for (final e in procedureProgress.entries) e.key: e.value.toJson(),
      };
    }
    /* 12 */ if (hasLabwork != d.hasLabwork) json['hasLabwork'] = hasLabwork;
    /* 13 */ if (labName != d.labName) json['labName'] = labName;
    /* 14 */ if (labworkNotes != d.labworkNotes) {
      json['labworkNotes'] = labworkNotes;
    }
    /* 15 */ if (labworkReceived != d.labworkReceived) {
      json['labworkReceived'] = labworkReceived;
    }
    /* 16 */ if (drawings.isNotEmpty) json['drawings'] = drawings;
    /* 17 */ if (duration != d.duration) json['duration'] = duration;
    /* 18 */ if (dcmImgs.isNotEmpty) json['dcmImgs'] = dcmImgs;
    /* 19 */ if (reminder24Sent != d.reminder24Sent) {
      json['reminder24Sent'] = reminder24Sent;
    }
    /* 20 */ if (reminder2Sent != d.reminder2Sent) {
      json['reminder2Sent'] = reminder2Sent;
    }
    /* 21 */ if (rescheduleRequested != d.rescheduleRequested) {
      json['rescheduleRequested'] = rescheduleRequested;
    }
    /* 22 */ if (isNoShow != d.isNoShow) json['isNoShow'] = isNoShow;
    /* 23 */ if (confirmWhatsAppSent != d.confirmWhatsAppSent) {
      json['confirmWhatsAppSent'] = confirmWhatsAppSent;
    }
    /* 24 */ if (noShowWhatsAppSent != d.noShowWhatsAppSent) {
      json['noShowWhatsAppSent'] = noShowWhatsAppSent;
    }
    /* 25 */ if (aftercareWhatsAppSent != d.aftercareWhatsAppSent) {
      json['aftercareWhatsAppSent'] = aftercareWhatsAppSent;
    }
    /* 26 */ if (treatmentPlanId != null && treatmentPlanId!.isNotEmpty) {
      json['treatmentPlanId'] = treatmentPlanId;
    }
    /* 27 */ if (briefConfirmDueMs != d.briefConfirmDueMs) {
      json['briefConfirmDueMs'] = briefConfirmDueMs ?? 0;
    }
    /* 28 */ if (briefConfirmSent != d.briefConfirmSent) {
      json['briefConfirmSent'] = briefConfirmSent;
    }

    json.remove("title"); // remove since it is a computed value in this case

    return json;
  }

  @override
  Map<String, dynamic> get jsonCopyForPush {
    return {
      "date": (date.millisecondsSinceEpoch / 60000).round(),
      "isDone": isDone,
      "archived": archived,
      "operatorsIDs": operatorsIDs,
    };
  }

  // Note: `dcmImgs` is intentionally NOT in pushIfChanged — adding X-rays
  // to an appointment should not notify the patient. Other devices learn
  // about new X-rays via the normal PocketBase sync, not push.
  @override
  List<String> get pushIfChanged =>
      ["date", "isDone", "archived", "operatorsIDs"];

  @override
  bool get pushOnCreation => true;

  @override
  List<String> get targetsToPushTo => [
        // once we've implemented the patient side, we should uncomment the following line
        if (patientID != null && patientID!.isNotEmpty) patientID!,
        ...operatorsIDs
      ];
}
