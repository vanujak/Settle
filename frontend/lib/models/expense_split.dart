import 'user.dart';

class ExpenseSplit {
  ExpenseSplit({
    required this.user,
    required this.amount,
  });

  final AppUser user;
  final double amount;

  factory ExpenseSplit.fromJson(Map<String, dynamic> json) {
    return ExpenseSplit(
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
      amount: (json['amount'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': user.id,
      'amount': amount,
    };
  }
}
