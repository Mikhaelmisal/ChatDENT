import 'package:chatdent/features/appointments/appointment_model.dart';
import 'package:chatdent/features/appointments/appointments_store.dart';
import 'package:chatdent/features/expenses/expenses_store.dart';
import 'package:chatdent/features/invoices/invoices_store.dart';
import 'package:chatdent/features/leads/leads_store.dart';
import 'package:chatdent/features/notes/notes_store.dart';
import 'package:chatdent/features/patients/patients_store.dart';
import 'package:chatdent/features/settings/settings_stores.dart';

initializeStores() {
  globalSettings.init();
  patients.init();
  appointments.init();

  appointments.observableMap.observe((events) {
    for (var event in events) {
      if (event.id == "__removed_all__" || event.id == "__ignore_view__") {
        for (var p in patients.docs.values) {
          p.nullifyLabels();
        }
        break;
      }
      final doc = event.document;
      if (doc is Appointment && doc.patientID != null) {
        patients.docs[doc.patientID!]?.nullifyLabels();
      }
    }
  });

  expenses.init();
  invoices.init();
  notes.init();
  leads.init();
}
