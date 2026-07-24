import 'package:intl/intl.dart';

final NumberFormat _moneyFormat = NumberFormat.decimalPattern('en_US');

String formatMoney(num value) {
  final rounded = value.round();
  return '\u09F3${_moneyFormat.format(rounded)}';
}

String formatShortDate(DateTime value) {
  return DateFormat('MMM d').format(value);
}

String formatMonth(DateTime value) {
  return DateFormat('MMMM yyyy').format(value);
}
