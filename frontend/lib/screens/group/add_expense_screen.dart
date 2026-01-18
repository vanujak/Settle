import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/expense.dart';
import '../../models/expense_split.dart';
import '../../models/group.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';

class AddExpenseArgs {
  const AddExpenseArgs({required this.group, this.expense});

  final Group group;
  final Expense? expense;
}

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key, required this.args});

  static const routeName = '/groups/add-expense';

  final AddExpenseArgs args;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final Map<String, TextEditingController> _splitControllers = {};
  bool _equalSplit = true;
  String? _payerId;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.args.group.members.isNotEmpty) {
      _payerId = widget.args.expense?.paidBy.id ?? widget.args.group.members.first.id;
    }
    for (final member in widget.args.group.members) {
      _splitControllers[member.id] = TextEditingController();
    }
    final expense = widget.args.expense;
    if (expense != null) {
      _descriptionController.text = expense.description;
      _amountController.text = expense.amount.toStringAsFixed(2);
      _equalSplit = _isEqualSplit(expense);
      for (final split in expense.splits) {
        final controller = _splitControllers[split.user.id];
        if (controller != null) {
          controller.text = split.amount.toStringAsFixed(2);
        }
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    for (final controller in _splitControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_payerId == null) {
      setState(() {
        _error = 'Please select who paid.';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final totalAmount = double.parse(_amountController.text.trim());
      final splits = _buildSplits(totalAmount);
      final payer = widget.args.group.members.firstWhere((member) => member.id == _payerId);
      final expense = Expense(
        id: widget.args.expense?.id ?? 'temp',
        description: _descriptionController.text.trim(),
        amount: totalAmount,
        paidBy: payer,
        splits: splits,
        createdAt: widget.args.expense?.createdAt ?? DateTime.now(),
      );
      final authProvider = context.read<AuthProvider>();
      if (widget.args.expense == null) {
        await context.read<GroupProvider>().addExpense(
              authProvider.token!,
              widget.args.group.id,
              expense,
            );
      } else {
        await context.read<GroupProvider>().updateExpense(
              authProvider.token!,
              widget.args.group.id,
              expense,
            );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (err) {
      setState(() {
        _error = err.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  List<ExpenseSplit> _buildSplits(double total) {
    if (_equalSplit) {
      final memberCount = widget.args.group.members.length;
      final equalShare = (total / memberCount);
      final splits = <ExpenseSplit>[];
      double allocated = 0;
      for (var i = 0; i < memberCount; i++) {
        final member = widget.args.group.members[i];
        double amount;
        if (i == memberCount - 1) {
          amount = double.parse((total - allocated).toStringAsFixed(2));
        } else {
          amount = double.parse(equalShare.toStringAsFixed(2));
          allocated += amount;
        }
        splits.add(ExpenseSplit(user: member, amount: amount));
      }
      return splits;
    }
    final splits = <ExpenseSplit>[];
    double runningTotal = 0;
    for (final member in widget.args.group.members) {
      final controller = _splitControllers[member.id]!;
      final value = controller.text.trim();
      if (value.isEmpty) continue;
      final amount = double.parse(value);
      runningTotal += amount;
      splits.add(ExpenseSplit(user: member, amount: amount));
    }
    if ((runningTotal - total).abs() > 0.01) {
      throw Exception('Split amounts must add up to total. Currently $runningTotal');
    }
    return splits;
  }

  void _toggleSplit(bool value) {
    setState(() {
      _equalSplit = value;
      if (_equalSplit) {
        for (final controller in _splitControllers.values) {
          controller.clear();
        }
      }
    });
  }

  bool _isEqualSplit(Expense expense) {
    if (expense.splits.length != widget.args.group.members.length) return false;
    final equalShare = double.parse((expense.amount / expense.splits.length).toStringAsFixed(2));
    for (final split in expense.splits) {
      if ((split.amount - equalShare).abs() > 0.01) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.args.group;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Total Amount'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter amount';
                  }
                  final amount = double.tryParse(value.trim());
                  if (amount == null || amount <= 0) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _payerId,
                decoration: const InputDecoration(labelText: 'Paid By'),
                items: group.members
                    .map(
                      (member) => DropdownMenuItem(
                        value: member.id,
                        child: Text(member.name.isEmpty ? member.email : member.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _payerId = value),
              ),
              const SizedBox(height: 24),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Split equally'),
                value: _equalSplit,
                onChanged: _toggleSplit,
              ),
              if (!_equalSplit)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: group.members
                      .map(
                        (member) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextFormField(
                            controller: _splitControllers[member.id],
                            decoration: InputDecoration(
                              labelText: 'Amount for ${member.name.isEmpty ? member.email : member.name}',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      )
                      .toList(),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Expense'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
