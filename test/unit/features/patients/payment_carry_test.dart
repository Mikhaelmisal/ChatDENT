import 'package:chatdent/features/patients/patient_model.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../helpers/model_factory.dart';

void main() {
  group('Patient.runningBalanceOf', () {
    test('underpaid first visit is still due on the next one', () {
      final first = testAppointment(
        id: 'a1',
        price: 10000,
        paid: 3000,
      );
      final second = testAppointment(
        id: 'a2',
        price: 0,
        paid: 0,
      );
      expect(
        Patient.runningBalanceOf([first, second], excludingAppointmentId: 'a2'),
        -7000,
      );
      expect(
        Patient.runningBalanceOf([first, second], excludingAppointmentId: 'a2') <
            0,
        isTrue,
      );
    });

    test('overpaid first visit is credit on the next one', () {
      final first = testAppointment(
        id: 'a1',
        price: 5000,
        paid: 8000,
      );
      expect(
        Patient.runningBalanceOf([first], excludingAppointmentId: 'a2'),
        3000,
      );
    });

    test('card through second visit is still underpaid after a partial payment',
        () {
      final first = testAppointment(id: 'a1', price: 3000, paid: 0);
      final second = testAppointment(id: 'a2', price: 0, paid: 1000);
      expect(Patient.runningBalanceOf([first, second]), -2000);
    });

    test('installment on visit two reduces what is still due', () {
      final first = testAppointment(id: 'a1', price: 10000, paid: 3000);
      final second = testAppointment(id: 'a2', price: 0, paid: 3000);
      expect(
        Patient.runningBalanceOf([first, second], excludingAppointmentId: 'a3'),
        -4000,
      );
    });
  });
}
