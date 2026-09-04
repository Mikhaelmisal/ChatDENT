import 'package:chatdent/features/appointments/appointment_model.dart';
import 'package:chatdent/features/invoices/invoice_model.dart';
import 'package:chatdent/features/login/login_controller.dart';
import 'package:chatdent/features/patients/patient_model.dart';
import 'package:chatdent/services/launch.dart';
import 'package:chatdent/services/network.dart';
import 'package:chatdent/utils/hash.dart';
import '../../core/save_local.dart';
import '../../core/save_remote.dart';
import '../network_actions/network_actions_controller.dart';
import '../../services/login.dart';
import '../../core/store.dart';

const _storeName = "invoices";

class Invoices extends Store<Invoice> {
  Invoices()
      : super(
          modeling: Invoice.fromJson,
          isDemo: launch.isDemo,
          onSyncStart: () {
            networkActions.isSyncing(networkActions.isSyncing() + 1);
          },
          onSyncEnd: () {
            networkActions.isSyncing(networkActions.isSyncing() - 1);
          },
        );

  @override
  init() {
    super.init();
    onLogoutCallbacks.add(endSession);

    login.activators[_storeName] = () async {
      await loaded;

      await deactivatePersistenceSession();
      await local?.dispose();
      local = SaveLocal(name: _storeName, uniqueId: simpleHash(login.url));
      await deleteMemoryAndLoadFromPersistence();
      if (!launch.isDemo) {
        remote = SaveRemote(
          pbInstance: login.pb!,
          storeName: _storeName,
          onOnlineStatusChange: (current) {
            if (network.isOnline() != current) {
              network.isOnline(current);
            }
          },
        );
      }
      return () async {
        loginCtrl.loadingIndicator("Synchronizing invoices");
        await synchronize();
        networkActions.syncCallbacks[_storeName] = synchronize;
        networkActions.reconnectCallbacks[_storeName] = remote!.checkOnline;

        network.onOnline[_storeName] = synchronize;
        network.onOffline[_storeName] = cancelRealtimeSub;
      };
    };
  }

  List<Invoice> forPatient(String patientId) {
    return present.values.where((i) => i.patientID == patientId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Invoice? forAppointment(String appointmentId) {
    for (final i in present.values) {
      if (i.appointmentID == appointmentId) return i;
    }
    return null;
  }

  /// Payment day as DDMMYYYY (clinic date style).
  static String paidDateStamp(DateTime paidOn) {
    final d = DateTime(paidOn.year, paidOn.month, paidOn.day);
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd$mm${d.year}';
  }

  String nextNumber(DateTime paidOn, {String? keepId}) {
    final stamp = paidDateStamp(paidOn);
    final prefix = 'INV-$stamp-';
    if (keepId != null) {
      final current = get(keepId);
      if (current != null && current.number.startsWith(prefix)) {
        return current.number;
      }
    }
    var maxN = 0;
    final re = RegExp('^${RegExp.escape(prefix)}(\\d+)\$');
    for (final inv in present.values) {
      if (inv.id == keepId) continue;
      final m = re.firstMatch(inv.number);
      if (m == null) continue;
      final n = int.tryParse(m.group(1)!) ?? 0;
      if (n > maxN) maxN = n;
    }
    return '$prefix${(maxN + 1).toString().padLeft(2, '0')}';
  }

  Invoice generateFromAppointment(Patient patient, Appointment appointment) {
    final existing = forAppointment(appointment.id);
    final credit = patient.creditBalance(excludingAppointmentId: appointment.id);
    final applied = credit > appointment.price ? appointment.price : credit;
    final invoice = existing ?? Invoice.fromJson({});
    invoice.number = nextNumber(appointment.date, keepId: existing?.id);
    invoice.patientID = patient.id;
    invoice.appointmentID = appointment.id;
    invoice.date = appointment.date;
    invoice.description = Invoice.treatmentDescription(appointment);
    invoice.price = appointment.price;
    invoice.creditApplied = applied;
    invoice.paid = appointment.paid;
    set(invoice);
    return invoice;
  }
}

final invoices = Invoices();
