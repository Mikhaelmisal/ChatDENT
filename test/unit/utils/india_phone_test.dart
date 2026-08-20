import 'package:chatdent/utils/india_phone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persist is 91 plus 10 digits with no spaces', () {
    expect(IndiaPhone.persist('9876543210'), '919876543210');
    expect(IndiaPhone.e164('9876543210'), '+919876543210');
  });

  test('isCompleteLocal requires exactly 10 digits', () {
    expect(IndiaPhone.isCompleteLocal('987654321'), isFalse);
    expect(IndiaPhone.isCompleteLocal('9876543210'), isTrue);
    expect(IndiaPhone.isCompleteLocal('98765432101'), isFalse);
  });

  test('localDigitsFrom strips country code and non-digits', () {
    expect(IndiaPhone.localDigitsFrom('+91 98765 43210'), '9876543210');
    expect(IndiaPhone.localDigitsFrom('919876543210'), '9876543210');
    expect(IndiaPhone.localDigitsFrom('98765'), '98765');
  });
}
