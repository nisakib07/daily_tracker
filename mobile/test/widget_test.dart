import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/features/app/money_master_app.dart';

void main() {
  testWidgets('shows Money Master shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MoneyMasterApp()));

    expect(find.text('Money Master'), findsOneWidget);
    expect(find.byIcon(Icons.account_balance_wallet), findsOneWidget);
  });
}
