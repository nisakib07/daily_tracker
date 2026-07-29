import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:money_master/data/ai_service.dart';
import 'package:money_master/data/money_chat_context.dart';

void main() {
  group('AiService.suggestBudgets', () {
    test('parses a successful response', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/ai/budget-suggestion');
        expect(request.headers['authorization'], 'Bearer test-token');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['avgMonthlyIncome'], 40000);
        return http.Response(
          jsonEncode({
            'summary': 'Cap spending at 32000 BDT to save 20%.',
            'suggestions': [
              {
                'category': 'Food',
                'amount': 15000,
                'rationale': 'Matches average.',
              },
            ],
          }),
          200,
        );
      });
      final service = AiService(
        client: client,
        tokenProvider: () => 'test-token',
      );

      final result = await service.suggestBudgets(
        avgMonthlyIncome: 40000,
        avgCategorySpending: const {'Food': 15000},
        categories: const ['Food'],
      );

      expect(result.summary, 'Cap spending at 32000 BDT to save 20%.');
      expect(result.amounts, {'Food': 15000});
    });

    test('throws when there is no signed-in token', () async {
      final service = AiService(
        client: MockClient((request) async => http.Response('{}', 200)),
        tokenProvider: () => null,
      );

      expect(
        () => service.suggestBudgets(
          avgMonthlyIncome: 40000,
          avgCategorySpending: const {},
          categories: const [],
        ),
        throwsA(isA<AiServiceException>()),
      );
    });

    test(
      'throws with the server error message on a non-200 response',
      () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({'error': 'GEMINI_API_KEY missing'}),
            503,
          );
        });
        final service = AiService(client: client, tokenProvider: () => 'token');

        await expectLater(
          service.suggestBudgets(
            avgMonthlyIncome: 40000,
            avgCategorySpending: const {},
            categories: const [],
          ),
          throwsA(
            isA<AiServiceException>().having(
              (e) => e.message,
              'message',
              'GEMINI_API_KEY missing',
            ),
          ),
        );
      },
    );

    test(
      'throws a generic message on a non-200 response with no body',
      () async {
        final client = MockClient((request) async => http.Response('', 500));
        final service = AiService(client: client, tokenProvider: () => 'token');

        await expectLater(
          service.suggestBudgets(
            avgMonthlyIncome: 40000,
            avgCategorySpending: const {},
            categories: const [],
          ),
          throwsA(
            isA<AiServiceException>().having(
              (e) => e.message,
              'message',
              'AI service returned an error (500).',
            ),
          ),
        );
      },
    );

    test('throws on a malformed (non-JSON) response body', () async {
      final client = MockClient(
        (request) async => http.Response('not json at all', 200),
      );
      final service = AiService(client: client, tokenProvider: () => 'token');

      expect(
        () => service.suggestBudgets(
          avgMonthlyIncome: 40000,
          avgCategorySpending: const {},
          categories: const [],
        ),
        throwsA(isA<AiServiceException>()),
      );
    });

    test('throws on a JSON response that is not an object', () async {
      final client = MockClient(
        (request) async => http.Response(jsonEncode([1, 2, 3]), 200),
      );
      final service = AiService(client: client, tokenProvider: () => 'token');

      expect(
        () => service.suggestBudgets(
          avgMonthlyIncome: 40000,
          avgCategorySpending: const {},
          categories: const [],
        ),
        throwsA(isA<AiServiceException>()),
      );
    });

    test(
      'throws when the request times out',
      () async {
        final client = MockClient((request) async {
          await Future<void>.delayed(const Duration(seconds: 30));
          return http.Response('{}', 200);
        });
        final service = AiService(client: client, tokenProvider: () => 'token');

        expect(
          () => service.suggestBudgets(
            avgMonthlyIncome: 40000,
            avgCategorySpending: const {},
            categories: const [],
          ),
          throwsA(isA<AiServiceException>()),
        );
      },
      timeout: const Timeout(Duration(seconds: 25)),
    );
  });

  group('AiService.suggestSpendingCuts', () {
    test('parses a successful response', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/ai/spending-insights');
        return http.Response(
          jsonEncode({
            'suggestions': [
              {
                'category': 'Food',
                'message': 'Food spending is up 100% from last month.',
                'estimatedMonthlySaving': 4000,
              },
            ],
          }),
          200,
        );
      });
      final service = AiService(client: client, tokenProvider: () => 'token');

      final result = await service.suggestSpendingCuts(
        income: 50000,
        thisMonthCategorySpending: const {'Food': 8000},
        lastMonthCategorySpending: const {'Food': 4000},
      );

      expect(result, hasLength(1));
      expect(result.single.category, 'Food');
      expect(result.single.estimatedMonthlySaving, 4000);
    });

    test('returns an empty list when the AI has nothing to suggest', () async {
      final client = MockClient(
        (request) async => http.Response(jsonEncode({'suggestions': []}), 200),
      );
      final service = AiService(client: client, tokenProvider: () => 'token');

      final result = await service.suggestSpendingCuts(
        income: 50000,
        thisMonthCategorySpending: const {},
        lastMonthCategorySpending: const {},
      );

      expect(result, isEmpty);
    });
  });

  group('AiService.askAboutMoney', () {
    const context = MoneyChatContext(
      currentBalance: 10000,
      totalToReceive: 0,
      totalToPay: 0,
      monthlySummaries: [],
    );

    test('returns the answer on a successful response', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/ai/chat');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['question'], 'How much did I spend on Food?');
        expect(body['history'], isEmpty);
        return http.Response(
          jsonEncode({'answer': 'You spent 8000 BDT on Food last month.'}),
          200,
        );
      });
      final service = AiService(client: client, tokenProvider: () => 'token');

      final answer = await service.askAboutMoney(
        question: 'How much did I spend on Food?',
        context: context,
        history: const [],
      );

      expect(answer, 'You spent 8000 BDT on Food last month.');
    });

    test('sends prior history turns in the request body', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final history = body['history'] as List;
        expect(history, hasLength(1));
        expect(history.single, {'role': 'user', 'text': 'hi'});
        return http.Response(jsonEncode({'answer': 'Hello!'}), 200);
      });
      final service = AiService(client: client, tokenProvider: () => 'token');

      await service.askAboutMoney(
        question: 'follow up',
        context: context,
        history: const [AiChatTurn(role: 'user', text: 'hi')],
      );
    });

    test('throws when the response has no answer field', () async {
      final client = MockClient(
        (request) async => http.Response(jsonEncode({}), 200),
      );
      final service = AiService(client: client, tokenProvider: () => 'token');

      expect(
        () => service.askAboutMoney(
          question: 'q',
          context: context,
          history: const [],
        ),
        throwsA(isA<AiServiceException>()),
      );
    });
  });

  group('AiService.explainHealthScore', () {
    test('returns the explanation on a successful response', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/ai/health-explanation');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['overall'], 72);
        expect(body['metrics'], hasLength(1));
        return http.Response(
          jsonEncode({
            'explanation':
                'Your Financial Cushion is excellent, keeping your score at 72.',
          }),
          200,
        );
      });
      final service = AiService(client: client, tokenProvider: () => 'token');

      final explanation = await service.explainHealthScore(
        overall: 72,
        grade: 'B',
        metrics: const [
          AiHealthMetricInput(
            label: 'Financial Cushion',
            score: 20,
            maxScore: 20,
            status: 'Excellent',
            insufficientData: false,
          ),
        ],
      );

      expect(
        explanation,
        'Your Financial Cushion is excellent, keeping your score at 72.',
      );
    });

    test('throws when the response has no explanation field', () async {
      final client = MockClient(
        (request) async => http.Response(jsonEncode({}), 200),
      );
      final service = AiService(client: client, tokenProvider: () => 'token');

      expect(
        () => service.explainHealthScore(
          overall: 72,
          grade: 'B',
          metrics: const [],
        ),
        throwsA(isA<AiServiceException>()),
      );
    });
  });
}
