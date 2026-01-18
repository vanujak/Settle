import 'expense.dart';
import 'user.dart';

class Group {
  Group({
    required this.id,
    required this.name,
    required this.description,
    required this.members,
    required this.expenses,
  });

  final String id;
  final String name;
  final String? description;
  final List<AppUser> members;
  final List<Expense> expenses;

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'].toString(),
      name: json['name'] as String,
      description: json['description'] as String?,
      members: (json['members'] as List<dynamic>)
          .map((item) => AppUser.fromJson(item as Map<String, dynamic>))
          .toList(),
      expenses: (json['expenses'] as List<dynamic>?)
              ?.map((item) => Expense.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
