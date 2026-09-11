import 'package:chatdent/features/appointments/appointment_procedure_carry.dart';
import 'package:chatdent/features/appointments/procedure_protocols.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('carryForwardOpenTreatments', () {
    test('next visit continues unfinished RCT on the same tooth', () {
      final teeth = <String, String>{};
      final progress = <String, ToothProcedureProgress>{};
      carryForwardOpenTreatments(
        teeth: teeth,
        progress: progress,
        priors: [
          ProcedureVisitSnapshot(
            teeth: {'11': 'rCT'},
            progress: {
              '11': ToothProcedureProgress(
                label: 'rCT',
                done: 2,
                fields: {'workingLength': '21'},
              ),
            },
          ),
        ],
      );

      expect(teeth['11'], 'rCT');
      expect(progress['11']!.done, 2);
      expect(progress['11']!.fields['workingLength'], '21');
    });

    test('does not copy a protocol that was fully completed', () {
      final rctSteps = protocolFor('rCT').steps.length;
      final teeth = <String, String>{};
      final progress = <String, ToothProcedureProgress>{};
      carryForwardOpenTreatments(
        teeth: teeth,
        progress: progress,
        priors: [
          ProcedureVisitSnapshot(
            teeth: {'11': 'rCT'},
            progress: {
              '11': ToothProcedureProgress(label: 'rCT', done: rctSteps),
            },
          ),
        ],
      );

      expect(teeth.containsKey('11'), isFalse);
      expect(progress.containsKey('11'), isFalse);
    });

    test('does not overwrite progress already recorded on this visit', () {
      final teeth = {'11': 'rCT'};
      final progress = {
        '11': ToothProcedureProgress(label: 'rCT', done: 3),
      };
      carryForwardOpenTreatments(
        teeth: teeth,
        progress: progress,
        priors: [
          ProcedureVisitSnapshot(
            teeth: {'11': 'rCT'},
            progress: {
              '11': ToothProcedureProgress(label: 'rCT', done: 1),
            },
          ),
        ],
      );

      expect(progress['11']!.done, 3);
    });
  });

  group('seedToothProgressFromPriors', () {
    test('resumes when the same tooth is marked again', () {
      final progress = {
        '36': ToothProcedureProgress(label: 'rCT'),
      };
      seedToothProgressFromPriors(
        iso: '36',
        label: 'rCT',
        progress: progress,
        priors: [
          ProcedureVisitSnapshot(
            teeth: {'36': 'rCT'},
            progress: {
              '36': ToothProcedureProgress(label: 'rCT', done: 4),
            },
          ),
        ],
      );
      expect(progress['36']!.done, 4);
    });
  });
}
