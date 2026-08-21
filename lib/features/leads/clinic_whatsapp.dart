import 'dart:convert';

import 'package:chatdent/features/appointments/appointment_model.dart';
import 'package:chatdent/features/appointments/appointments_store.dart';
import 'package:chatdent/features/leads/clinic_hours.dart';
import 'package:chatdent/features/leads/whatsapp_templates.dart';
import 'package:chatdent/features/outreach/campaign_settings.dart';
import 'package:chatdent/features/patients/patient_model.dart';
import 'package:chatdent/features/patients/patients_store.dart';
import 'package:chatdent/features/prescriptions/prescription_line.dart';
import 'package:chatdent/features/settings/settings_stores.dart';
import 'package:chatdent/services/login.dart';
import 'package:chatdent/utils/india_phone.dart';
import 'package:chatdent/utils/logger.dart';
import 'package:http/http.dart' as http;

/// Sends clinic WhatsApp via Evolution. Failures are logged; they never block save.
///
/// Message rules:
/// - Walk-in: no welcome / confirm while at the clinic.
/// - On leave (visit done): one combined message (welcome + Rx if any + thanks),
///   no maps/location. Clinic banner image first when configured.
/// - ~18 minutes later: brief next-appointment note (if booked).
/// - Day-before reminder (n8n): different copy from confirm; no maps.
/// - Held / archived / deleted patients: no outbound WhatsApp.
class ClinicWhatsApp {
  static const briefConfirmDelay = Duration(minutes: 18);

  static final Map<String, Future<void>> _briefTimers = {};

  static EvolutionSettings get _evo => EvolutionSettings.fromJsonString(
        globalSettings.get(EvolutionSettings.settingId).value,
      );

  static String? _digitsFor(Patient? patient) {
    if (patient == null) return null;
    final digits = IndiaPhone.localDigitsFrom(patient.phonesString);
    if (digits.length == 10) return '91$digits';
    final raw = patient.phonesString.replaceAll(RegExp(r'\D'), '');
    if (raw.length >= 10) return raw;
    return null;
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final x = a.toLocal();
    final y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  /// True when we must not send any WhatsApp to this patient.
  static bool mustNotMessage(Patient? patient) {
    if (patient == null) return true;
    if (patient.archived == true) return true;
    if (patient.whatsappHold) return true;
    return false;
  }

  /// True if this patient already got the post-visit WhatsApp today.
  static bool hadPostVisitWhatsAppToday(Patient patient) {
    final now = DateTime.now();
    return appointments.present.values.any((a) =>
        a.patientID == patient.id &&
        a.aftercareWhatsAppSent &&
        _sameDay(a.date, now));
  }

  /// Public URL for clinic banner / flyer (Evolution sendMedia).
  static String? clinicBannerUrl() {
    final campaign = WhatsAppCampaign.fromJsonString(
      globalSettings.campaignJson,
    );
    final marketing = campaign.marketingImageUrl.trim();
    if (marketing.isNotEmpty) return marketing;
    final file = campaign.flyerFile.trim();
    if (file.isEmpty) return null;
    final base = login.url.trim().replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) return null;
    return '$base/api/files/data/${WhatsAppCampaign.flyerRecordId}/$file';
  }

  static Future<void> sendText({
    required String number,
    required String text,
  }) async {
    final body = sanitizeWhatsAppText(text);
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (body.isEmpty || digits.length < 10) return;
    final evo = _evo;
    final base = evo.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final key = evo.apiKey.trim();
    final instance =
        evo.instance.trim().isEmpty ? 'clinic_default' : evo.instance.trim();
    if (base.isEmpty || key.isEmpty) {
      logger('ClinicWhatsApp skipped: Evolution not configured', null, 3);
      return;
    }
    try {
      final res = await http
          .post(
            Uri.parse('$base/message/sendText/$instance'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'apikey': key,
            },
            body: utf8.encode(jsonEncode({
              'number': digits,
              'text': body,
            })),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        logger(
          'ClinicWhatsApp send failed ${res.statusCode}: ${res.body}',
          null,
          2,
        );
      }
    } catch (e) {
      logger('ClinicWhatsApp send skipped: $e', null, 3);
    }
  }

  /// Sends clinic banner as image so WhatsApp shows it instead of a Maps card.
  static Future<void> sendBannerImage({
    required String number,
    String caption = '',
  }) async {
    final media = clinicBannerUrl();
    if (media == null || media.isEmpty) return;
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return;
    final evo = _evo;
    final base = evo.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final key = evo.apiKey.trim();
    final instance =
        evo.instance.trim().isEmpty ? 'clinic_default' : evo.instance.trim();
    if (base.isEmpty || key.isEmpty) return;
    try {
      final res = await http
          .post(
            Uri.parse('$base/message/sendMedia/$instance'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'apikey': key,
            },
            body: utf8.encode(jsonEncode({
              'number': digits,
              'mediatype': 'image',
              'mimetype': 'image/jpeg',
              'caption': sanitizeWhatsAppText(caption),
              'media': media,
            })),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        logger(
          'ClinicWhatsApp banner failed ${res.statusCode}: ${res.body}',
          null,
          2,
        );
      }
    } catch (e) {
      logger('ClinicWhatsApp banner skipped: $e', null, 3);
    }
  }

  /// Only for phone-call intake. Walk-ins get WhatsApp when they leave.
  static Future<void> sendForNewPatient(Patient patient) async {
    if (mustNotMessage(patient)) return;
    if (patient.intakeSource != PatientIntakeSource.phoneCall) return;
    final number = _digitsFor(patient);
    if (number == null) return;
    await sendBannerImage(number: number);
    final name = patient.title;
    final text = filledWhatsAppNote(
      WhatsAppTemplateIds.welcomeConfirm,
      name: name,
    );
    final fallback = filledWhatsAppNote(
      WhatsAppTemplateIds.confirm,
      name: name,
    );
    await sendText(
      number: number,
      text: text.isNotEmpty ? text : fallback,
    );
  }

  /// Remote / phone bookings only. Skip walk-ins and same-day post-visit.
  static Future<void> sendAppointmentBooked({
    required Appointment appointment,
    required Patient patient,
    bool useWelcomeConfirm = false,
  }) async {
    if (mustNotMessage(patient)) return;
    if (patient.intakeSource == PatientIntakeSource.walkIn) return;
    if (hadPostVisitWhatsAppToday(patient)) return;
    final number = _digitsFor(patient);
    if (number == null) return;
    await sendBannerImage(number: number);
    final id = useWelcomeConfirm
        ? WhatsAppTemplateIds.welcomeConfirm
        : WhatsAppTemplateIds.confirm;
    var text = filledWhatsAppNote(
      id,
      name: patient.title,
      when: appointment.date,
    );
    if (text.isEmpty && useWelcomeConfirm) {
      text = filledWhatsAppNote(
        WhatsAppTemplateIds.confirm,
        name: patient.title,
        when: appointment.date,
      );
    }
    await sendText(number: number, text: text);
  }

  static Future<void> sendNoShow({
    required Appointment appointment,
    required Patient patient,
  }) async {
    if (mustNotMessage(patient)) return;
    final number = _digitsFor(patient);
    if (number == null) return;
    final text = filledWhatsAppNote(
      WhatsAppTemplateIds.noShow,
      name: patient.title,
      when: appointment.date,
    );
    await sendText(number: number, text: text);
  }

  static Future<void> sendReschedule({
    required Appointment appointment,
    required Patient patient,
  }) async {
    if (mustNotMessage(patient)) return;
    final number = _digitsFor(patient);
    if (number == null) return;
    await sendBannerImage(number: number);
    final text = filledWhatsAppNote(
      WhatsAppTemplateIds.reschedule,
      name: patient.title,
      when: appointment.date,
    );
    await sendText(number: number, text: text);
  }

  /// Walk-in leave: banner + welcome + optional Rx + caring thanks (no maps).
  /// Then schedule a brief next-appointment message ~18 minutes later.
  static Future<void> sendVisitLeavePack({
    required Appointment appointment,
    required Patient patient,
  }) async {
    if (mustNotMessage(patient)) return;
    final number = _digitsFor(patient);
    if (number == null) return;

    await sendBannerImage(number: number);

    var rxNote = '';
    if (appointment.prescriptions.isNotEmpty) {
      final formatted =
          PrescriptionLine.formatWhatsAppNote(appointment.prescriptions);
      if (formatted.isNotEmpty) {
        rxNote = 'Your prescription:\n$formatted\n\n';
      }
    }

    var text = filledWhatsAppNote(
      WhatsAppTemplateIds.leave,
      name: patient.title,
      when: appointment.date,
      note: rxNote,
    );
    if (text.isEmpty) {
      if (rxNote.isNotEmpty) {
        text = filledWhatsAppNote(
          WhatsAppTemplateIds.prescription,
          name: patient.title,
          when: appointment.date,
          note: PrescriptionLine.formatWhatsAppNote(appointment.prescriptions),
        );
      } else {
        text = filledWhatsAppNote(
          WhatsAppTemplateIds.aftercare,
          name: patient.title,
          when: appointment.date,
        );
      }
    }
    await sendText(number: number, text: text);

    final next = _nextFutureAppointment(patient.id, after: appointment);
    if (next != null) {
      next.briefConfirmDueMs =
          DateTime.now().add(briefConfirmDelay).millisecondsSinceEpoch;
      next.briefConfirmSent = false;
      appointments.set(next);
      scheduleBriefConfirm(next.id);
    }
  }

  /// Patient leaving clinic: leave pack (replaces single Rx-or-aftercare).
  static Future<void> sendTreatmentDone({
    required Appointment appointment,
    required Patient patient,
  }) async {
    await sendVisitLeavePack(appointment: appointment, patient: patient);
  }

  /// Prescription + hope you feel better + phone + team (single message).
  static Future<void> sendPrescription({
    required Appointment appointment,
    required Patient patient,
  }) async {
    if (mustNotMessage(patient)) return;
    final number = _digitsFor(patient);
    if (number == null) return;
    if (appointment.prescriptions.isEmpty) return;
    final note = PrescriptionLine.formatWhatsAppNote(appointment.prescriptions);
    if (note.isEmpty) return;
    await sendBannerImage(number: number);
    final text = filledWhatsAppNote(
      WhatsAppTemplateIds.prescription,
      name: patient.title,
      when: appointment.date,
      note: note,
    );
    await sendText(number: number, text: text);
  }

  static Appointment? _nextFutureAppointment(
    String patientId, {
    Appointment? after,
  }) {
    final now = DateTime.now();
    final afterMs = after?.date.millisecondsSinceEpoch ?? 0;
    Appointment? best;
    for (final a in appointments.present.values) {
      if (a.patientID != patientId) continue;
      if (a.isDone || a.archived == true || a.isNoShow) continue;
      if (after != null && a.id == after.id) continue;
      final start = a.date.millisecondsSinceEpoch;
      if (start <= now.millisecondsSinceEpoch) continue;
      if (start <= afterMs) continue;
      if (best == null || a.date.isBefore(best.date)) best = a;
    }
    return best;
  }

  static void scheduleBriefConfirm(String appointmentId) {
    _briefTimers[appointmentId] = () async {
      final due = appointments.get(appointmentId);
      if (due == null) return;
      final waitMs = (due.briefConfirmDueMs ?? 0) - DateTime.now().millisecondsSinceEpoch;
      if (waitMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: waitMs));
      }
      await sendBriefNextAppointment(appointmentId);
    }();
  }

  static Future<void> sendBriefNextAppointment(String appointmentId) async {
    final appointment = appointments.get(appointmentId);
    if (appointment == null) return;
    if (appointment.briefConfirmSent) return;
    if (appointment.isDone || appointment.archived == true) return;
    final patientId = appointment.patientID;
    if (patientId == null || patientId.isEmpty) return;
    final patient = patients.get(patientId);
    if (patient == null || mustNotMessage(patient)) return;
    final number = _digitsFor(patient);
    if (number == null) return;

    await sendBannerImage(number: number);
    final text = filledWhatsAppNote(
      WhatsAppTemplateIds.nextBrief,
      name: patient.title,
      when: appointment.date,
    );
    if (text.isEmpty) return;
    await sendText(number: number, text: text);
    appointment.briefConfirmSent = true;
    appointment.briefConfirmDueMs = null;
    appointments.set(appointment);
  }

  /// Catch up overdue brief confirms after restart / sync.
  static Future<void> flushPendingBriefConfirms() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final a in appointments.present.values.toList()) {
      if (a.briefConfirmSent) continue;
      final due = a.briefConfirmDueMs;
      if (due == null || due <= 0) continue;
      if (due > now) {
        scheduleBriefConfirm(a.id);
        continue;
      }
      await sendBriefNextAppointment(a.id);
    }
  }
}
