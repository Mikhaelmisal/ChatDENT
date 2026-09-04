import 'package:chatdent/core/model.dart';
import 'package:chatdent/features/appointments/appointment_model.dart';
import 'package:chatdent/features/appointments/appointments_store.dart';
import 'package:chatdent/features/patients/patient_model.dart';
import 'package:chatdent/features/patients/patients_store.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:chatdent/services/login.dart';
import 'package:chatdent/utils/constants.dart';
import 'package:chatdent/utils/iso_to_textual.dart';

class Invoice extends Model {
  @override
  bool get locked => login.perm(Perm.appointments).none;

  @override
  String get title => number.isEmpty ? txt("invoice") : number;

  String patientID = "";
  String appointmentID = "";
  String number = "";
  DateTime date = DateTime.now();
  String description = "";
  double price = 0;
  double creditApplied = 0;
  double paid = 0;

  Patient? get patient => patients.get(patientID);

  Appointment? get appointment =>
      appointmentID.isEmpty ? null : appointments.get(appointmentID);

  double get amountDue {
    final due = price - creditApplied;
    return due > 0 ? due : 0;
  }

  double get balance => amountDue - paid;

  Invoice.fromJson(super.json) : super.fromJson();

  @override
  Invoice copy(bool blank) {
    return Invoice.fromJson(blank ? {} : toJson());
  }

  static String treatmentDescription(Appointment appointment) {
    final parts = <String>[];
    for (final e in appointment.teeth.entries) {
      try {
        parts.add('${isoToTextualNotation(e.key)}: ${e.value}');
      } catch (_) {
        parts.add('${e.key}: ${e.value}');
      }
    }
    if (appointment.postOpNotes.trim().isNotEmpty) {
      parts.add(appointment.postOpNotes.trim());
    } else if (appointment.preOpNotes.trim().isNotEmpty) {
      parts.add(appointment.preOpNotes.trim());
    }
    if (parts.isEmpty) return txt("appointment");
    return parts.join(" · ");
  }

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    patientID = json['patientID'] ?? patientID;
    appointmentID = json['appointmentID'] ?? appointmentID;
    number = json['number'] ?? number;
    date = json['date'] != null
        ? DateTime.fromMillisecondsSinceEpoch(
            json['date'] is int
                ? json['date'] as int
                : (json['date'] as num).toInt(),
          )
        : date;
    description = json['description'] ?? description;
    price = double.parse((json['price'] ?? price).toString());
    creditApplied =
        double.parse((json['creditApplied'] ?? creditApplied).toString());
    paid = double.parse((json['paid'] ?? paid).toString());
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    final d = Invoice.fromJson({});
    if (patientID != d.patientID) json['patientID'] = patientID;
    if (appointmentID != d.appointmentID) {
      json['appointmentID'] = appointmentID;
    }
    if (number != d.number) json['number'] = number;
    json['date'] = date.millisecondsSinceEpoch;
    if (description != d.description) json['description'] = description;
    if (price != d.price) json['price'] = price;
    if (creditApplied != d.creditApplied) {
      json['creditApplied'] = creditApplied;
    }
    if (paid != d.paid) json['paid'] = paid;
    return json;
  }
}
