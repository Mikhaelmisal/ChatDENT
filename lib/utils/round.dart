import 'dart:math';

double roundToPrecision(double value, int precision) {
  final multiplier = pow(10, precision);
  return (value * multiplier).round() / multiplier;
}
