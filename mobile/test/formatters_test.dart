import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/core/formatters.dart';

void main() {
  test('whole Taka show without paisa', () {
    expect(formatMoney(250), '৳250');
    expect(formatMoney(1234567), '৳1,234,567');
    expect(formatMoney(0), '৳0');
  });

  test('paisa show when there are any', () {
    expect(formatMoney(18.5), '৳18.50');
    expect(formatMoney(1234.56), '৳1,234.56');
    expect(formatMoney(1234.567), '৳1,234.57');
    expect(formatMoney(0.4), '৳0.40');
  });

  test('floating-point leftovers never show', () {
    expect(formatMoney(0.1 + 0.2), '৳0.30');
    expect(formatMoney(100.0000000001), '৳100');
    expect(formatMoney(0.004), '৳0');
    expect(formatMoney(-0.001), '৳0');
  });

  test('negative amounts keep their sign', () {
    expect(formatMoney(-839), '৳-839');
    expect(formatMoney(-18.5), '৳-18.50');
  });
}
