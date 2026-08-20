import 'package:fluent_ui/fluent_ui.dart';

Color? colorBasedOnPayments(double paid, double price) {
  bool isOOverPaid = paid > price;
  bool isUnderpaid = paid < price;
  return isOOverPaid
      ? Colors.blue
      : isUnderpaid
          ? Colors.warningPrimaryColor
          : null;
}
