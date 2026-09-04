import 'package:chatdent/app/chatdent_theme.dart';
import 'package:chatdent/common_widgets/button_styles.dart';
import 'package:chatdent/core/multi_stream_builder.dart';
import 'package:chatdent/features/appointments/appointment_model.dart';
import 'package:chatdent/features/appointments/appointments_store.dart';
import 'package:chatdent/features/appointments/open_appointment_panel.dart';
import 'package:chatdent/features/patients/patient_model.dart';
import 'package:chatdent/features/prescriptions/prescription_line.dart';
import 'package:chatdent/features/leads/clinic_whatsapp.dart';
import 'package:chatdent/features/settings/settings_stores.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:chatdent/services/login.dart';
import 'package:chatdent/utils/constants.dart';
import 'package:chatdent/utils/print/print_prescription.dart';
import 'package:fluent_ui/fluent_ui.dart';

/// Patient panel tab: prescription cards per visit (not the medicine catalog).
class PatientPrescriptions extends StatelessWidget {
  final Patient patient;
  const PatientPrescriptions(this.patient, {super.key});

  List<Appointment> get _withRx {
    return patient.allAppointments
        .where((a) => a.prescriptions.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return MStreamBuilder(
      streams: [appointments.observableMap.stream],
      builder: (context, _) {
        final apts = _withRx;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (apts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: InfoBar(title: Txt(txt('noPrescriptionsYet'))),
              )
            else
              ...apts.map((apt) => _PrescriptionVisitCard(
                    patient: patient,
                    appointment: apt,
                  )),
          ],
        );
      },
    );
  }
}

class _PrescriptionVisitCard extends StatelessWidget {
  final Patient patient;
  final Appointment appointment;
  const _PrescriptionVisitCard({
    required this.patient,
    required this.appointment,
  });

  @override
  Widget build(BuildContext context) {
    final p = ChatDentPalette.of(context);
    final lines = appointment.prescriptions
        .map((p) => PrescriptionLine.parse(p).toDisplay())
        .toList();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: chatDentInnerCard(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(FluentIcons.pill, size: 16),
              Txt(
                '${txt("prescription")} · ${DF.commonDate(appointment.date)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Button(
                onPressed: () {
                  final canViewPostOp = login.perm(Perm.postOp).exact(2) ||
                      (login.perm(Perm.postOp).exact(1) &&
                          appointment.operatorsIDs
                              .contains(login.currentAccountID));
                  // Tabs: 0 appointment, [1 operative], then prescription.
                  openAppointment(appointment, canViewPostOp ? 2 : 1);
                },
                child: ButtonContent(FluentIcons.edit, txt('edit')),
              ),
            ],
          ),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Txt('• $line'),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Button(
                onPressed: () {
                  printingPrescription(
                    context,
                    lines,
                    patient.title,
                    patient.age.toString(),
                    patient.link ?? '',
                  );
                },
                child: ButtonContent(FluentIcons.print, txt('printPrescription')),
              ),
              Button(
                onPressed: () {
                  ClinicWhatsApp.sendPrescription(
                    appointment: appointment,
                    patient: patient,
                  );
                },
                child: ButtonContent(
                  FluentIcons.office_chat,
                  txt('sendOnWhatsApp'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
