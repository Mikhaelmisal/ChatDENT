import 'package:chatdent/features/accounts/accounts_controller.dart';
import 'package:chatdent/features/appointments/appointment_model.dart';
import 'package:chatdent/features/appointments/appointments_store.dart';
import 'package:chatdent/features/leads/clinic_hours.dart';
import 'package:chatdent/features/leads/clinic_whatsapp.dart';
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

class DoctorBoard {
  final String operatorId;
  final String name;
  final List<Appointment> today;
  final List<FreeSlot> free;

  const DoctorBoard({
    required this.operatorId,
    required this.name,
    required this.today,
    required this.free,
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
      durationMinutes: durationMinutes ?? hours.slotMinutes,
      operatorId: operatorId,
      limit: limit,
      busy: occupied(),
    );
  }

  List<String> bookingOperatorIds() {
    final ops = accounts.operators.map((a) => a.id).toList();
    if (ops.isNotEmpty) return ops;
    if (hours.defaultOperatorId.isNotEmpty) return [hours.defaultOperatorId];
    if (login.currentAccountID.isNotEmpty) return [login.currentAccountID];
    return [''];
  }

  List<int> freeSlotStarts({
    required DateTime day,
    required String operatorId,
    DateTime? now,
  }) {
    final duration = hours.slotMinutes;
    final clock = now ?? DateTime.now();
    final busy = occupied();
    final starts = <int>[];
    for (final m in hours.slotStartsForLocalDate(day)) {
      final start = DateTime(day.year, day.month, day.day, m ~/ 60, m % 60);
      if (!start.isAfter(clock)) continue;
      final end = start.add(Duration(minutes: duration));
      if (engine.isFree(
        start: start,
        end: end,
        operatorId: operatorId,
        busy: busy,
      )) {
        starts.add(m);
      }
    }
    return starts;
  }

  List<Appointment> bookedOn({
    required String operatorId,
    required DateTime day,
  }) {
    return appointments.present.values
        .where((a) =>
            a.archived != true &&
            (operatorId.isEmpty || a.operatorsIDs.contains(operatorId)) &&
            _isSameLocalDay(a.date, day))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  bool _isSameLocalDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  List<DoctorBoard> doctorBoards({int freeLimit = 8}) {
    final now = DateTime.now();
    final busy = occupied();
    return [
      for (final id in bookingOperatorIds())
        DoctorBoard(
          operatorId: id,
          name: id.isEmpty ? '' : accounts.nameOrEmailFromID(id),
          today: appointments.present.values
              .where((a) =>
                  a.archived != true &&
                  a.operatorsIDs.contains(id) &&
                  _isSameLocalDay(a.date, now))
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date)),
          free: engine.getFreeSlots(
            from: now,
            days: 7,
            durationMinutes: hours.slotMinutes,
            operatorId: id.isEmpty ? null : id,
            limit: freeLimit,
            busy: busy,
          ),
        ),
    ];
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
      'intakeSource': PatientIntakeSource.phoneCall,
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

    final patient = ensurePatient(lead);
    if (patient.intakeSource != PatientIntakeSource.phoneCall) {
      patient.intakeSource = PatientIntakeSource.phoneCall;
      patients.set(patient);
    }
    final operatorIds = op.isNotEmpty
        ? [op]
        : (login.currentAccountID.isNotEmpty ? [login.currentAccountID] : <String>[]);

    final appointment = Appointment.fromJson({
      'patientID': patient.id,
      'date': (slot.start.millisecondsSinceEpoch / 60000).round(),
      'duration': duration,
      'operatorsIDs': operatorIds,
      if (lead.interest.trim().isNotEmpty) 'preOpNotes': lead.interest.trim(),
    });
    appointments.set(appointment);

    lead.patientID = patient.id;
    lead.appointmentID = appointment.id;
    lead.stage = LeadStage.scheduled;
    lead.called = true;
    lead.coming = true;
    lead.callOutcome = CallOutcome.booked;
    lead.lastContactedAt = DateTime.now();
    leads.set(lead);

    final name = lead.title.isEmpty ? patient.title : lead.title;
    final useCombined = !patient.welcomeWhatsAppSent;
    final fromNote = filledWhatsAppNote(
      useCombined
          ? WhatsAppTemplateIds.welcomeConfirm
          : WhatsAppTemplateIds.confirm,
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

    patient.welcomeWhatsAppSent = true;
    appointment.confirmWhatsAppSent = true;
    patients.set(patient);
    appointments.set(appointment);
    ClinicWhatsApp.sendText(number: e164, text: text);

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
