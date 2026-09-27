import 'package:intl/intl.dart';

final NumberFormat _moneyFormat = NumberFormat.decimalPattern('en_US');
final NumberFormat _paisaFormat = NumberFormat('#,##0.00', 'en_US');

/// Formats Taka, showing paisa only when there are any: ৳250, ৳18.50,
/// ৳1,234.56. Rounding to whole Taka used to hide fees and make balances
/// disagree with the bank or bKash. Works in whole paisa, so floating-point
/// leftovers (0.1 + 0.2) never show and a tiny negative never prints "-0".
String formatMoney(num value) {
  final paisa = (value * 100).round();
  if (paisa % 100 == 0) {
    return '৳${_moneyFormat.format(paisa ~/ 100)}';
  }
  return '৳${_paisaFormat.format(paisa / 100)}';
}

String formatShortDate(DateTime value) {
  return DateFormat('MMM d').format(value);
}

String formatMonth(DateTime value) {
  return DateFormat('MMMM yyyy').format(value);
}
