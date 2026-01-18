import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../models/group.dart';
import '../models/user.dart';
import '../services/group_service.dart';

class GroupProvider extends ChangeNotifier {
  GroupProvider(this._groupService);

  final GroupService _groupService;
  final List<Group> _groups = [];
  Group? _selectedGroup;
  bool _loading = false;
  String? _error;

  List<Group> get groups => List.unmodifiable(_groups);
  Group? get selectedGroup => _selectedGroup;
  bool get loading => _loading;
  String? get error => _error;
  List<Map<String, dynamic>> _balances = [];
  List<Map<String, dynamic>> get balances => List.unmodifiable(_balances);

  Future<void> loadGroups(String token) async {
    _loading = true;
    notifyListeners();
    try {
      final result = await _groupService.fetchGroups(token);
      _groups
        ..clear()
        ..addAll(result.map((item) => Group.fromJson(item as Map<String, dynamic>)));
      _error = null;
      _selectedGroup = null;
      _balances = [];
    } catch (err) {
      _error = err.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> selectGroup(String token, String groupId) async {
    _loading = true;
    notifyListeners();
    try {
      final data = await _groupService.fetchGroupDetails(token, groupId);
      _selectedGroup = Group.fromJson(data);
      _balances = [];
      _error = null;
    } catch (err) {
      _error = err.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> fetchBalances(String token, String groupId) async {
    _loading = true;
    notifyListeners();
    try {
      final result = await _groupService.fetchBalances(token, groupId);
      _balances = result
          .map((item) => Map<String, dynamic>.from(item as Map<String, dynamic>))
          .toList();
      _error = null;
    } catch (err) {
      _error = err.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> createGroup(
    String token, {
    required String name,
    String? description,
    required List<AppUser> members,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      final data = await _groupService.createGroup(
        token,
        name: name,
        description: description,
        memberIds: members.map((member) => member.id).toList(),
      );
      final newGroup = Group.fromJson(data);
      _groups.add(newGroup);
      _error = null;
    } catch (err) {
      _error = err.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addExpense(
    String token,
    String groupId,
    Expense expense,
  ) async {
    _loading = true;
    notifyListeners();
    try {
      final payload = expense.toJson();
      final data = await _groupService.addExpense(token, groupId, payload);
      _selectedGroup = Group.fromJson(data);
      _error = null;
    } catch (err) {
      _error = err.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> updateExpense(
    String token,
    String groupId,
    Expense expense,
  ) async {
    _loading = true;
    notifyListeners();
    try {
      final payload = expense.toJson();
      final data = await _groupService.updateExpense(token, groupId, expense.id, payload);
      _selectedGroup = Group.fromJson(data);
      _error = null;
    } catch (err) {
      _error = err.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> deleteExpense(
    String token,
    String groupId,
    String expenseId,
  ) async {
    _loading = true;
    notifyListeners();
    try {
      await _groupService.deleteExpense(token, groupId, expenseId);
      if (_selectedGroup != null) {
        final updatedExpenses = _selectedGroup!.expenses.where((expense) => expense.id != expenseId).toList();
        _selectedGroup = Group(
          id: _selectedGroup!.id,
          name: _selectedGroup!.name,
          description: _selectedGroup!.description,
          members: _selectedGroup!.members,
          expenses: updatedExpenses,
        );
      }
      _error = null;
    } catch (err) {
      _error = err.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
