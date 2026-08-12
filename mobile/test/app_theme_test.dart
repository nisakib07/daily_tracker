import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/shared/theme/app_theme.dart';

void main() {
  group('AppTheme.colorForLabel', () {
    test('is deterministic for the same label', () {
      expect(AppTheme.colorForLabel('Food'), AppTheme.colorForLabel('Food'));
      expect(
        AppTheme.colorForLabel('Rickshaw'),
        AppTheme.colorForLabel('Rickshaw'),
      );
    });

    test('is case- and whitespace-insensitive', () {
      expect(AppTheme.colorForLabel('Food'), AppTheme.colorForLabel('food'));
      expect(AppTheme.colorForLabel('Food'), AppTheme.colorForLabel(' FOOD '));
    });

    test('always returns a color from the identity palette', () {
      for (final label in ['Food', 'Transport', 'Bills', 'Onil Bhai', '']) {
        expect(
          AppTheme.identityPalette,
          contains(AppTheme.colorForLabel(label)),
        );
      }
    });

    test('spreads different labels across more than one color', () {
      final colors = {
        for (final label in [
          'Food',
          'Transport',
          'Bills',
          'Entertainment',
          'Rent',
        ])
          AppTheme.colorForLabel(label),
      };
      expect(colors.length, greaterThan(1));
    });
  });
}
