import 'expense_split.dart';
import 'user.dart';

class Expense {
  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.splits,
    required this.createdAt,
  });

  final String id;
  final String description;
  final double amount;
  final AppUser paidBy;
  final List<ExpenseSplit> splits;
  final DateTime createdAt;

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'].toString(),
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
      paidBy: AppUser.fromJson(json['paidBy'] as Map<String, dynamic>),
      splits: (json['splits'] as List<dynamic>)
          .map((item) => ExpenseSplit.fromJson(item as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'amount': amount,
      'paidById': paidBy.id,
      'splits': splits.map((split) => split.toJson()).toList(),
    };
  }
}
