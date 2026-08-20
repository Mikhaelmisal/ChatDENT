import 'package:chatdent/utils/dd_mm_yyyy_input_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TextEditingValue fmt(String input, [String oldInput = '']) {
    return ddMmYyyyInputFormatter.formatEditUpdate(
      TextEditingValue(text: oldInput),
      TextEditingValue(text: input),
    );
  }

  test('inserts slash after DD', () {
    expect(fmt('1').text, '1');
    expect(fmt('15', '1').text, '15/');
  });

  test('inserts slash after MM', () {
    expect(fmt('15/0', '15/').text, '15/0');
    expect(fmt('15/03', '15/0').text, '15/03/');
  });

  test('completes YYYY without extra slash', () {
    expect(fmt('15/03/1990', '15/03/199').text, '15/03/1990');
  });

  test('strips non-digits and caps at 8 digits', () {
    expect(fmt('15a03b1990xx').text, '15/03/1990');
    expect(fmt('150319901234').text, '15/03/1990');
  });

  test('backspace after auto slash does not immediately restore it', () {
    expect(fmt('15', '15/').text, '15');
    expect(fmt('15/03', '15/03/').text, '15/03');
  });

  group('DD 1-31', () {
    test('auto-pads days 4-9', () {
      expect(fmt('4').text, '04/');
      expect(fmt('9').text, '09/');
    });

    test('rejects day 00 and 32+', () {
      expect(fmt('00', '0').text, '0');
      expect(fmt('32', '3').text, '3');
      expect(fmt('39', '3').text, '3');
    });

    test('allows 01-31', () {
      expect(fmt('01', '0').text, '01/');
      expect(fmt('31', '3').text, '31/');
    });
  });

  group('MM 1-12', () {
    test('auto-pads months 2-9', () {
      expect(fmt('15/2', '15/').text, '15/02/');
    });

    test('rejects month 00 and 13+', () {
      expect(fmt('15/00', '15/0').text, '15/0');
      expect(fmt('15/13', '15/1').text, '15/1');
      expect(fmt('15/19', '15/1').text, '15/1');
    });

    test('allows 01-12', () {
      expect(fmt('15/01', '15/0').text, '15/01/');
      expect(fmt('15/12', '15/1').text, '15/12/');
    });
  });

  group('YYYY 1900-current year', () {
    test('rejects years before 1900', () {
      expect(fmt('15/03/1', '15/03/').text, '15/03/1');
      expect(fmt('15/03/18', '15/03/1').text, '15/03/1');
      expect(fmt('15/03/1899', '15/03/189').text, '15/03/189');
    });

    test('allows 1900', () {
      expect(fmt('15/03/1900', '15/03/190').text, '15/03/1900');
    });

    test('rejects years after the current year', () {
      final nextYear = DateTime.now().year + 1;
      expect(
        fmt('15/03/$nextYear', '15/03/${nextYear.toString().substring(0, 3)}')
            .text,
        '15/03/${nextYear.toString().substring(0, 3)}',
      );
    });

    test('allows the current year', () {
      final year = DateTime.now().year;
      expect(fmt('15/03/$year', '15/03/${year.toString().substring(0, 3)}').text,
          '15/03/$year');
    });
  });
}
