import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';
import 'money_chat_context.dart';

/// Thrown for any failure calling the AI backend - network, auth, timeout,
/// or a malformed/error response. Callers are expected to catch this and
/// fall back to the on-device suggestion rather than surface it directly.
class AiServiceException implements Exception {
  const AiServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AiBudgetSuggestion {
  const AiBudgetSuggestion({required this.summary, required this.amounts});

  final String summary;
  final Map<String, double> amounts;

  factory AiBudgetSuggestion.fromJson(Map<String, dynamic> json) {
    final rows = (json['suggestions'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row));

    return AiBudgetSuggestion(
      summary: json['summary']?.toString() ?? '',
      amounts: {
        for (final row in rows)
          if (row['category'] != null && row['amount'] is num)
            row['category'].toString(): (row['amount'] as num).toDouble(),
      },
    );
  }
}

class AiSpendCutSuggestion {
  const AiSpendCutSuggestion({
    required this.category,
    required this.message,
    required this.estimatedMonthlySaving,
  });

  final String category;
  final String message;
  final double estimatedMonthlySaving;

  factory AiSpendCutSuggestion.fromJson(Map<String, dynamic> json) {
    return AiSpendCutSuggestion(
      category: json['category']?.toString() ?? 'Uncategorized',
      message: json['message']?.toString() ?? '',
      estimatedMonthlySaving: ((json['estimatedMonthlySaving'] as num?) ?? 0)
          .toDouble(),
    );
  }
}

class AiParsedTransaction {
  const AiParsedTransaction({
    required this.type,
    required this.amount,
    required this.category,
    required this.note,
  });

  final String type;
  final double amount;
  final String category;
  final String note;

  factory AiParsedTransaction.fromJson(Map<String, dynamic> json) {
    final rawType = json['type']?.toString();
    if (rawType != 'income' && rawType != 'expense') {
      throw const AiServiceException(
        'Unexpected response from the AI service.',
      );
    }
    final amount = json['amount'];
    if (amount is! num || amount <= 0) {
      throw const AiServiceException(
        'Unexpected response from the AI service.',
      );
    }
    return AiParsedTransaction(
      type: rawType!,
      amount: amount.toDouble(),
      category: json['category']?.toString() ?? 'Uncategorized',
      note: json['note']?.toString() ?? '',
    );
  }
}

/// One turn of prior conversation sent back to the chat endpoint so it can
/// answer follow-up questions with context.
class AiChatTurn {
  const AiChatTurn({required this.role, required this.text});

  final String role;
  final String text;

  Map<String, dynamic> toJson() => {'role': role, 'text': text};
}

/// A single health-score metric, sent to the health-explanation endpoint.
class AiHealthMetricInput {
  const AiHealthMetricInput({
    required this.label,
    required this.score,
    required this.maxScore,
    required this.status,
    required this.insufficientData,
  });

  final String label;
  final int score;
  final int maxScore;
  final String status;
  final bool insufficientData;

  Map<String, dynamic> toJson() => {
    'label': label,
    'score': score,
    'maxScore': maxScore,
    'status': status,
    'insufficientData': insufficientData,
  };
}

/// Calls the Gemini-backed suggestion endpoints on the deployed web app.
/// The mobile app never talks to Gemini directly - it has nowhere safe to
/// hold an API key - so this just authenticates with the user's existing
/// Supabase session and posts already-aggregated numbers.
class AiService {
  AiService({http.Client? client, String? Function()? tokenProvider})
    : _client = client ?? http.Client(),
      _tokenProvider = tokenProvider ?? _defaultTokenProvider;

  final http.Client _client;
  final String? Function() _tokenProvider;
  static const _timeout = Duration(seconds: 20);

  static String? _defaultTokenProvider() =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  Future<AiBudgetSuggestion> suggestBudgets({
    required double avgMonthlyIncome,
    required Map<String, double> avgCategorySpending,
    required List<String> categories,
  }) async {
    final json = await _post('/api/ai/budget-suggestion', {
      'avgMonthlyIncome': avgMonthlyIncome,
      'avgCategorySpending': [
        for (final entry in avgCategorySpending.entries)
          {'category': entry.key, 'amount': entry.value},
      ],
      'categories': categories,
    });
    return AiBudgetSuggestion.fromJson(json);
  }

  Future<List<AiSpendCutSuggestion>> suggestSpendingCuts({
    required double income,
    required Map<String, double> thisMonthCategorySpending,
    required Map<String, double> lastMonthCategorySpending,
  }) async {
    final json = await _post('/api/ai/spending-insights', {
      'income': income,
      'thisMonthCategorySpending': [
        for (final entry in thisMonthCategorySpending.entries)
          {'category': entry.key, 'amount': entry.value},
      ],
      'lastMonthCategorySpending': [
        for (final entry in lastMonthCategorySpending.entries)
          {'category': entry.key, 'amount': entry.value},
      ],
    });

    final rows = (json['suggestions'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (row) =>
              AiSpendCutSuggestion.fromJson(Map<String, dynamic>.from(row)),
        );
    return rows.toList();
  }

  Future<AiParsedTransaction> parseTransactionText({
    required String text,
    required List<String> incomeCategories,
    required List<String> expenseCategories,
  }) async {
    final json = await _post('/api/ai/parse-transaction', {
      'text': text,
      'incomeCategories': incomeCategories,
      'expenseCategories': expenseCategories,
    });
    return AiParsedTransaction.fromJson(json);
  }

  Future<String> askAboutMoney({
    required String question,
    required MoneyChatContext context,
    required List<AiChatTurn> history,
  }) async {
    final json = await _post('/api/ai/chat', {
      'question': question,
      'context': context.toJson(),
      'history': history.map((turn) => turn.toJson()).toList(),
    });
    final answer = json['answer'];
    if (answer is! String) {
      throw const AiServiceException(
        'Unexpected response from the AI service.',
      );
    }
    return answer;
  }

  Future<String> explainHealthScore({
    required int overall,
    required String grade,
    required List<AiHealthMetricInput> metrics,
  }) async {
    final json = await _post('/api/ai/health-explanation', {
      'overall': overall,
      'grade': grade,
      'metrics': metrics.map((metric) => metric.toJson()).toList(),
    });
    final explanation = json['explanation'];
    if (explanation is! String) {
      throw const AiServiceException(
        'Unexpected response from the AI service.',
      );
    }
    return explanation;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = _tokenProvider();
    if (token == null) {
      throw const AiServiceException('Not signed in.');
    }

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('${AppConfig.webAppUrl}$path'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const AiServiceException(
        'The AI service took too long to respond.',
      );
    } catch (_) {
      throw const AiServiceException('Could not reach the AI service.');
    }

    if (response.statusCode != 200) {
      throw AiServiceException(
        _extractError(response.body) ??
            'AI service returned an error (${response.statusCode}).',
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const AiServiceException(
          'Unexpected response from the AI service.',
        );
      }
      return decoded;
    } on FormatException {
      throw const AiServiceException(
        'Unexpected response from the AI service.',
      );
    }
  }

  String? _extractError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } catch (_) {
      // Fall through to the generic message.
    }
    return null;
  }
}
