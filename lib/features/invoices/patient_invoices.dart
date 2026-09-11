import 'package:chatdent/app/chatdent_theme.dart';
import 'package:chatdent/common_widgets/appointment_card.dart';
import 'package:chatdent/common_widgets/button_styles.dart';
import 'package:chatdent/core/multi_stream_builder.dart';
import 'package:chatdent/features/appointments/appointment_model.dart';
import 'package:chatdent/features/appointments/appointments_store.dart';
import 'package:chatdent/features/appointments/open_appointment_panel.dart';
import 'package:chatdent/features/invoices/invoice_model.dart';
import 'package:chatdent/features/invoices/invoices_store.dart';
import 'package:chatdent/features/patients/patient_model.dart';
import 'package:chatdent/features/settings/settings_stores.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:chatdent/utils/color_based_on_payment.dart';
import 'package:chatdent/utils/print/print_invoice.dart';
import 'package:fluent_ui/fluent_ui.dart';

class PatientInvoices extends StatelessWidget {
  final Patient patient;
  const PatientInvoices(this.patient, {super.key});

  List<Appointment> get _billable {
    return patient.allAppointments
        .where((a) => a.price != 0 || a.paid != 0)
        .toList()
        .reversed
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return MStreamBuilder(
      streams: [
        appointments.observableMap.stream,
        invoices.observableMap.stream,
      ],
      builder: (context, _) {
        final billed = _billable;
        final missing = billed
            .where((a) => invoices.forAppointment(a.id) == null)
            .toList();
        final credit = patient.creditBalance();
        final outstanding = patient.outstandingBalance();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (credit > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: InfoBar(
                  isLong: true,
                  title: Txt(
                    '${txt("creditBalance")}: ${credit.toStringAsFixed(2)} ${currency()}',
                  ),
                  content: Txt(txt("creditAppliedNextHint")),
                  severity: InfoBarSeverity.success,
                ),
              ),
            if (outstanding > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: InfoBar(
                  isLong: true,
                  title: Txt(
                    '${txt("outstandingBalance")}: ${outstanding.toStringAsFixed(2)} ${currency()}',
                  ),
                  content: Txt(txt("outstandingAppliedNextHint")),
                  severity: InfoBarSeverity.warning,
                ),
              ),
            if (missing.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Button(
                  onPressed: () {
                    for (final a in missing) {
                      invoices.generateFromAppointment(patient, a);
                    }
                  },
                  child: ButtonContent(
                    FluentIcons.add,
                    txt("generateInvoices"),
                  ),
                ),
              ),
            if (billed.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: InfoBar(title: Txt(txt('noInvoicesYet'))),
              )
            else ...[
              ...billed.map((apt) {
                final inv = invoices.forAppointment(apt.id);
                if (inv != null) {
                  return _InvoiceCard(patient: patient, invoice: inv);
                }
                return _PendingVisitCard(patient: patient, appointment: apt);
              }),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 12, 50),
                child: Builder(builder: (context) {
                  final p = ChatDentPalette.of(context);
                  return Container(
                    padding: const EdgeInsets.all(6),
                    decoration: chatDentInnerCard(p).copyWith(
                      boxShadow: chatDentPopupShadow(p),
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: 4,
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: (colorBasedOnPayments(
                                        patient.paymentsMade,
                                        patient.pricesGiven) ??
                                    p.fluentBlue)
                                .withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Txt(
                            "${txt("paymentSummary")} (${currency()})",
                            style: TextStyle(
                              fontFamily: ChatDentFonts.ui,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: p.muted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Divider(),
                        const SizedBox(height: 15),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            PaymentPill(
                              finalTextColor: p.muted,
                              title: txt("cost"),
                              amount: patient.pricesGiven.toStringAsFixed(2),
                            ),
                            PaymentPill(
                              finalTextColor: p.muted,
                              title: txt("paid"),
                              amount: patient.paymentsMade.toStringAsFixed(2),
                            ),
                            PaymentPill(
                              finalTextColor: p.muted,
                              title: patient.overPaid
                                  ? txt("overpaid")
                                  : patient.underPaid
                                      ? txt("underpaid")
                                      : txt("fullyPaid"),
                              amount: (patient.paymentsMade - patient.pricesGiven)
                                  .abs()
                                  .toStringAsFixed(2),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PendingVisitCard extends StatelessWidget {
  final Patient patient;
  final Appointment appointment;
  const _PendingVisitCard({
    required this.patient,
    required this.appointment,
  });

  @override
  Widget build(BuildContext context) {
    final p = ChatDentPalette.of(context);
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
              const Icon(FluentIcons.money, size: 16),
              Txt(
                '${txt("appointment")} · ${DF.commonDate(appointment.date)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Button(
                onPressed: () {
                  invoices.generateFromAppointment(patient, appointment);
                },
                child: ButtonContent(FluentIcons.add, txt('generateInvoice')),
              ),
            ],
          ),
          Txt(Invoice.treatmentDescription(appointment)),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              PaymentPill(
                finalTextColor: p.muted,
                title: txt("price"),
                amount: appointment.price.toStringAsFixed(2),
              ),
              PaymentPill(
                finalTextColor: p.muted,
                title: txt("paid"),
                amount: appointment.paid.toStringAsFixed(2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final Patient patient;
  final Invoice invoice;
  const _InvoiceCard({
    required this.patient,
    required this.invoice,
  });

  @override
  Widget build(BuildContext context) {
    final p = ChatDentPalette.of(context);
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
              const Icon(FluentIcons.money, size: 16),
              Txt(
                '${invoice.number} · ${DF.commonDate(invoice.date)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (invoice.appointment != null)
                Button(
                  onPressed: () => openAppointment(invoice.appointment),
                  child: ButtonContent(FluentIcons.edit, txt('edit')),
                ),
            ],
          ),
          Txt(invoice.description),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              PaymentPill(
                finalTextColor: p.muted,
                title: txt("price"),
                amount: invoice.price.toStringAsFixed(2),
              ),
              if (invoice.creditApplied > 0)
                PaymentPill(
                  finalTextColor: p.muted,
                  title: txt("creditApplied"),
                  amount: invoice.creditApplied.toStringAsFixed(2),
                ),
              PaymentPill(
                finalTextColor: p.muted,
                title: txt("amountDue"),
                amount: invoice.amountDue.toStringAsFixed(2),
              ),
              PaymentPill(
                finalTextColor: p.muted,
                title: txt("paid"),
                amount: invoice.paid.toStringAsFixed(2),
              ),
              PaymentPill(
                finalTextColor: p.muted,
                title: txt("invoiceBalance"),
                amount: invoice.balance.toStringAsFixed(2),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Button(
                onPressed: () {
                  printingInvoice(
                    context,
                    invoice: invoice,
                    patient: patient,
                  );
                },
                child: ButtonContent(FluentIcons.print, txt('printInvoice')),
              ),
              if (invoice.appointment != null)
                Button(
                  onPressed: () {
                    invoices.generateFromAppointment(
                      patient,
                      invoice.appointment!,
                    );
                  },
                  child: ButtonContent(
                    FluentIcons.refresh,
                    txt('regenerateInvoice'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
