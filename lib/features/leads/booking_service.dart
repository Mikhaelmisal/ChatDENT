import 'package:chatdent/features/appointments/appointment_model.dart';
import 'package:chatdent/features/appointments/appointments_store.dart';
import 'package:chatdent/features/leads/clinic_hours.dart';
import 'package:chatdent/features/leads/lead_model.dart';
import 'package:chatdent/features/leads/leads_store.dart';
import 'package:chatdent/features/leads/slot_engine.dart';
import 'package:chatdent/features/leads/whatsapp_templates.dart';
import 'package:chatdent/features/patients/patient_model.dart';
import 'package:chatdent/features/patients/patients_store.dart';
import 'package:chatdent/features/settings/settings_stores.dart';
import 'package:chatdent/services/login.dart';
import 'package:chatdent/utils/india_phone.dart';

class BookSlotException implements Exception {
  final String message;
  BookSlotException(this.message);
  @override
  String toString() => message;
}

class BookSlotResult {
  final Appointment appointment;
  final Patient patient;
  final Lead lead;
  final String whatsappText;
  final String whatsappUrl;

  const BookSlotResult({
    required this.appointment,
    required this.patient,
    required this.lead,
    required this.whatsappText,
    required this.whatsappUrl,
  });
}

class BookingService {
  ClinicHours get hours =>
      ClinicHours.fromJsonString(globalSettings.get(ClinicHours.settingId).value);

  EvolutionSettings get evolution => EvolutionSettings.fromJsonString(
      globalSettings.get(EvolutionSettings.settingId).value);

  SlotEngine get engine => SlotEngine(hours);

  List<OccupiedInterval> occupied() {
    return appointments.present.values
        .where((a) => a.archived != true)
        .map(OccupiedInterval.fromAppointment)
        .toList();
  }

  List<FreeSlot> nextSlots({
    int days = 14,
    int? durationMinutes,
    String? operatorId,
    int limit = 12,
  }) {
    return engine.getFreeSlots(
      from: DateTime.now(),
      days: days,
      durationMinutes: durationMinutes,
      operatorId: operatorId,
      limit: limit,
      busy: occupied(),
    );
  }

  Patient ensurePatient(Lead lead) {
    if (lead.patientID.isNotEmpty) {
      final existing = patients.get(lead.patientID);
      if (existing != null) return existing;
    }
    if (lead.phonesString.isNotEmpty) {
      for (final p in patients.present.values) {
        if (p.phonesString == lead.phonesString) {
          lead.patientID = p.id;
          return p;
        }
      }
    }
    final patient = Patient.fromJson({
      'title': lead.title,
      if (lead.phonesString.isNotEmpty) 'phone': lead.phonesString,
      if (lead.email.isNotEmpty) 'email': lead.email,
      'notes': [
        if (lead.source.isNotEmpty) 'Lead source: ${lead.source}',
        if (lead.campaign.isNotEmpty) 'Campaign: ${lead.campaign}',
        if (lead.notes.isNotEmpty) lead.notes,
      ].join('\n'),
    });
    patients.set(patient);
    lead.patientID = patient.id;
    return patient;
  }

  BookSlotResult book({
    required Lead lead,
    required FreeSlot slot,
    int? durationMinutes,
    String? operatorId,
  }) {
    final duration = durationMinutes ?? hours.slotMinutes;
    final op = (operatorId != null && operatorId.isNotEmpty)
        ? operatorId
        : (slot.operatorId.isNotEmpty
            ? slot.operatorId
            : hours.defaultOperatorId);
    final end = slot.start.add(Duration(minutes: duration));
    if (!engine.isFree(
      start: slot.start,
      end: end,
      operatorId: op,
      busy: occupied(),
    )) {
      throw BookSlotException('slotTaken');
    }

    final patient = ensurePatient(lead);
    final operatorIds = op.isNotEmpty
        ? [op]
        : (login.currentAccountID.isNotEmpty ? [login.currentAccountID] : <String>[]);

    final appointment = Appointment.fromJson({
      'patientID': patient.id,
      'date': (slot.start.millisecondsSinceEpoch / 60000).round(),
      'duration': duration,
      'operatorsIDs': operatorIds,
      'preOpNotes': lead.interest.isNotEmpty
          ? lead.interest
          : 'Booked from lead',
    });
    appointments.set(appointment);

    lead.patientID = patient.id;
    lead.appointmentID = appointment.id;
    lead.stage = LeadStage.scheduled;
    lead.lastContactedAt = DateTime.now();
    leads.set(lead);

    final name = lead.title.isEmpty ? patient.title : lead.title;
    final fromNote = filledWhatsAppNote(
      WhatsAppTemplateIds.confirm,
      name: name,
      when: slot.start,
    );
    final text = fromNote.isNotEmpty
        ? fromNote
        : evolution.fill(
            evolution.confirmTemplate,
            name: name,
            when: slot.start,
          );
    final digits = IndiaPhone.localDigitsFrom(lead.phonesString);
    final e164 = digits.length == 10 ? '91$digits' : lead.phonesString;
    final url =
        'https://wa.me/$e164?text=${Uri.encodeComponent(text)}';

    return BookSlotResult(
      appointment: appointment,
      patient: patient,
      lead: lead,
      whatsappText: text,
      whatsappUrl: url,
    );
  }
}

final booking = BookingService();
