import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:money_master/data/ai_service.dart';
import 'package:money_master/data/money_repository.dart';
import 'package:money_master/features/insights/money_chat_sheet.dart';
import 'package:money_master/models/money_models.dart';
import 'package:money_master/shared/theme/app_theme.dart';

void main() {
  final now = DateTime.now();
  final account = Account(
    id: 'account-1',
    name: 'Cash',
    type: 'cash',
    createdAt: now,
  );
  final snapshot = DashboardSnapshot(
    accounts: [account],
    people: const [],
    investments: const [],
    budgets: const [],
    transactions: [
      TransactionRecord(
        id: 'income',
        type: 'income',
        amount: 50000,
        toAccountId: account.id,
        category: 'Salary',
        occurredAt: now,
        createdAt: now,
      ),
    ],
  );

  testWidgets('Shows an empty-state hint before any question is asked', (
    tester,
  ) async {
    await _pump(tester, MoneyChatSheet(snapshot: snapshot));
    await tester.pumpAndSettle();

    expect(find.text('Ask about your money'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A successful question shows the user and AI bubbles', (
    tester,
  ) async {
    final aiService = AiService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({'answer': 'You spent 8000 BDT on Food last month.'}),
          200,
        ),
      ),
      tokenProvider: () => 'fake-token',
    );

    await _pump(
      tester,
      MoneyChatSheet(snapshot: snapshot, aiService: aiService),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('money-chat-input')),
      'How much did I spend on Food last month?',
    );
    await tester.tap(find.byKey(const ValueKey('money-chat-send')));
    await tester.pumpAndSettle();

    expect(
      find.text('How much did I spend on Food last month?'),
      findsOneWidget,
    );
    expect(find.text('You spent 8000 BDT on Food last month.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A failed question shows an error notice, not a fake reply', (
    tester,
  ) async {
    final aiService = AiService(
      client: MockClient(
        (request) async => http.Response('Service Unavailable', 503),
      ),
      tokenProvider: () => 'fake-token',
    );

    await _pump(
      tester,
      MoneyChatSheet(snapshot: snapshot, aiService: aiService),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('money-chat-input')),
      'How much did I spend on Food last month?',
    );
    await tester.tap(find.byKey(const ValueKey('money-chat-send')));
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't reach the AI service — try again in a moment."),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: child));
}
