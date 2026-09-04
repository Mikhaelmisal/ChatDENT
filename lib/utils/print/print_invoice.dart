import 'package:chatdent/features/invoices/invoice_model.dart';
import 'package:chatdent/features/patients/patient_model.dart';
import 'package:chatdent/features/settings/settings_stores.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:chatdent/utils/print/print.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:bidi/bidi.dart' as bidi;

Future<void> printingInvoice(
  BuildContext context, {
  required Invoice invoice,
  required Patient patient,
}) async {
  String vis(String s) => String.fromCharCodes(bidi.logicalToVisual(s));
  final cur = currency();
  pw.Widget row(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(vis(label)),
          pw.Text(
            vis(value),
            style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null,
          ),
        ],
      ),
    );
  }

  if (!context.mounted) return;
  return printing(
    context,
    vis("${txt("invoice")} ${invoice.number}"),
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(vis("${txt("patient")}: ${patient.title}")),
        pw.SizedBox(height: 4),
        pw.Text(vis("${txt("date")}: ${DF.commonDate(invoice.date)}")),
        if (patient.age > 0) ...[
          pw.SizedBox(height: 4),
          pw.Text(vis("${txt("age")}: ${patient.age}")),
        ],
        pw.SizedBox(height: 10),
        pw.Text(vis("${txt("description")}:")),
        pw.SizedBox(height: 4),
        pw.Text(vis(invoice.description)),
        pw.SizedBox(height: 12),
        pw.Divider(),
        row("${txt("price")} ($cur)", invoice.price.toStringAsFixed(2)),
        if (invoice.creditApplied > 0)
          row(
            "${txt("creditApplied")} ($cur)",
            invoice.creditApplied.toStringAsFixed(2),
          ),
        row(
          "${txt("amountDue")} ($cur)",
          invoice.amountDue.toStringAsFixed(2),
        ),
        row("${txt("paid")} ($cur)", invoice.paid.toStringAsFixed(2)),
        pw.Divider(),
        row(
          "${txt("invoiceBalance")} ($cur)",
          invoice.balance.toStringAsFixed(2),
          bold: true,
        ),
      ],
    ),
    vis(
      "${globalSettings.prescriptionFooter}\n${txt("invoice")} · ${DF.allNumbers(DateTime.now())}\n${globalSettings.phone}",
    ),
  );
}
