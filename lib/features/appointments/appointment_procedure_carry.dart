import 'package:chatdent/features/appointments/appointment_model.dart';
import 'package:chatdent/features/appointments/procedure_protocols.dart';

class ProcedureVisitSnapshot {
  final Map<String, String> teeth;
  final Map<String, ToothProcedureProgress> progress;
  const ProcedureVisitSnapshot({
    required this.teeth,
    required this.progress,
  });
}

ToothProcedureProgress _cloneProgress(ToothProcedureProgress p) {
  return ToothProcedureProgress(
    label: p.label,
    done: p.done,
    fields: Map<String, String>.from(p.fields),
  );
}

bool isProcedureIncomplete(ToothProcedureProgress progress) {
  final n = protocolFor(progress.label).steps.length;
  return n > 0 && progress.done < n;
}

ToothProcedureProgress? bestPriorProgressForTooth({
  required String iso,
  required String label,
  required List<ProcedureVisitSnapshot> priors,
}) {
  ToothProcedureProgress? best;
  for (final visit in priors) {
    if (visit.teeth[iso] != label) continue;
    final prior = visit.progress[iso];
    if (prior == null || prior.label != label) continue;
    if (best == null || prior.done > best.done) {
      best = prior;
    }
  }
  return best;
}

void seedToothProgressFromPriors({
  required String iso,
  required String label,
  required Map<String, ToothProcedureProgress> progress,
  required List<ProcedureVisitSnapshot> priors,
}) {
  final prior = bestPriorProgressForTooth(
    iso: iso,
    label: label,
    priors: priors,
  );
  if (prior == null) return;
  final cur = progress[iso];
  if (cur == null || cur.label != label) {
    progress[iso] = _cloneProgress(prior);
    return;
  }
  if (cur.done == 0 && cur.fields.isEmpty) {
    progress[iso] = _cloneProgress(prior);
  }
}

void carryForwardOpenTreatments({
  required Map<String, String> teeth,
  required Map<String, ToothProcedureProgress> progress,
  required List<ProcedureVisitSnapshot> priors,
}) {
  final unfinished = <String, ToothProcedureProgress>{};
  for (final visit in priors) {
    for (final e in visit.progress.entries) {
      final iso = e.key;
      final prior = e.value;
      if (visit.teeth[iso] != prior.label) continue;
      if (!isProcedureIncomplete(prior)) continue;
      final seen = unfinished[iso];
      if (seen == null || prior.done > seen.done) {
        unfinished[iso] = prior;
      }
    }
  }

  for (final e in unfinished.entries) {
    final iso = e.key;
    final prior = e.value;
    if (!teeth.containsKey(iso)) {
      teeth[iso] = prior.label;
      progress[iso] = _cloneProgress(prior);
    } else if (teeth[iso] == prior.label) {
      seedToothProgressFromPriors(
        iso: iso,
        label: prior.label,
        progress: progress,
        priors: priors,
      );
    }
  }
  syncAppointmentProcedureProgress(teeth, progress);
}

List<ProcedureVisitSnapshot> priorProcedureVisitsOf(Appointment appointment) {
  return (appointment.patient?.allAppointments ?? [])
      .where((a) => a.id != appointment.id)
      .map(
        (a) => ProcedureVisitSnapshot(
          teeth: a.teeth,
          progress: a.procedureProgress,
        ),
      )
      .toList();
}

void continueOpenProceduresFromPriorVisits(Appointment appointment) {
  carryForwardOpenTreatments(
    teeth: appointment.teeth,
    progress: appointment.procedureProgress,
    priors: priorProcedureVisitsOf(appointment),
  );
}

void seedProcedureFromPriorVisits(Appointment appointment, String iso) {
  final label = appointment.teeth[iso];
  if (label == null) return;
  seedToothProgressFromPriors(
    iso: iso,
    label: label,
    progress: appointment.procedureProgress,
    priors: priorProcedureVisitsOf(appointment),
  );
}
