// Reading money amounts typed into forms, shared by every amount field so
// they accept and reject the same things.

/// The largest single amount accepted: ৳100 crore. Anything bigger is
/// almost certainly a typo (an extra few zeros).
const maxAmount = 1000000000.0;

final _separators = RegExp(r'[\s,৳]');
final _amountPattern = RegExp(r'^(\d+\.?\d{0,2}|\.\d{1,2})$');
final _tooManyDecimals = RegExp(r'^\d*\.\d{3,}$');

/// The amount in [text], or null when it isn't one. Thousands separators
/// ("1,000"), spaces and a ৳ sign are allowed; at most two decimal places;
/// no signs, exponents, NaN or Infinity (which double.tryParse accepts).
double? parseAmount(String? text) {
  final cleaned = _clean(text);
  if (!_amountPattern.hasMatch(cleaned)) return null;
  return double.parse(cleaned.startsWith('.') ? '0$cleaned' : cleaned);
}

/// A form validator for an amount field. With [required] false an empty
/// field is fine; with [allowZero] a zero is.
String? validateAmount(
  String? text, {
  bool required = true,
  bool allowZero = false,
}) {
  final cleaned = _clean(text);
  if (cleaned.isEmpty) return required ? 'Enter an amount' : null;
  if (_tooManyDecimals.hasMatch(cleaned)) {
    return 'Use at most 2 decimal places';
  }
  final amount = parseAmount(cleaned);
  if (amount == null) return 'Enter a number, like 250 or 18.50';
  if (amount == 0 && !allowZero) return 'Enter an amount greater than 0';
  if (amount > maxAmount) return "That's over ৳100 crore. Check the amount";
  return null;
}

String _clean(String? text) => (text ?? '').trim().replaceAll(_separators, '');
