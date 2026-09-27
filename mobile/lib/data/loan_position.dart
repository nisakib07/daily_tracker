import '../models/money_models.dart';

/// Transaction types that make up a loan between you and a person.
const loanTransactionTypes = {'borrow', 'lend', 'repay', 'receive'};

/// Where you stand with one person, worked out from their loan
/// transactions. Shared by the Ledger tab, a person's history and the loan
/// forms so they always agree.
class LoanPosition {
  const LoanPosition({
    required this.theyOwe,
    required this.youOwe,
    this.lastActivityAt,
  });

  static const settled = LoanPosition(theyOwe: 0, youOwe: 0);

  /// What they owe you, never negative.
  final double theyOwe;

  /// What you owe them, never negative.
  final double youOwe;

  final DateTime? lastActivityAt;

  /// Positive when they owe you on net, negative when you owe them.
  double get netBalance => _cents(theyOwe - youOwe);

  factory LoanPosition.from(Iterable<TransactionRecord> transactions) {
    var theyOwe = 0.0; // lent, minus what they've paid back
    var youOwe = 0.0; // borrowed, minus what you've paid back
    DateTime? lastActivityAt;

    for (final transaction in transactions) {
      switch (transaction.type) {
        case 'borrow':
          youOwe += transaction.amount;
        case 'lend':
          theyOwe += transaction.amount;
        case 'repay':
          youOwe -= transaction.amount;
        case 'receive':
          theyOwe -= transaction.amount;
        default:
          continue;
      }
      final activityAt = transaction.displayDate;
      if (lastActivityAt == null || activityAt.isAfter(lastActivityAt)) {
        lastActivityAt = activityAt;
      }
    }

    // Paying back more than was owed doesn't vanish: the excess is now owed
    // the other way. Cutting each side off at zero used to drop it.
    if (youOwe < 0) {
      theyOwe -= youOwe;
      youOwe = 0;
    }
    if (theyOwe < 0) {
      youOwe -= theyOwe;
      theyOwe = 0;
    }

    return LoanPosition(
      theyOwe: _cents(theyOwe),
      youOwe: _cents(youOwe),
      lastActivityAt: lastActivityAt,
    );
  }
}

/// Rounds to whole paisa so floating-point leftovers (0.1 + 0.2 - 0.3) don't
/// keep a settled person on the ledger.
double _cents(double value) => (value * 100).round() / 100;
