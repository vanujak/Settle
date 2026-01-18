import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/expense.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import 'add_expense_screen.dart';
import 'balance_summary_screen.dart';

class GroupDetailArgs {
  const GroupDetailArgs({required this.groupId, required this.groupName});

  final String groupId;
  final String groupName;
}

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key, required this.args});

  static const routeName = '/groups/detail';

  final GroupDetailArgs args;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  bool _initialized = false;
    final _currencyFormatter = NumberFormat.simpleCurrency();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadGroup();
    }
  }

  Future<void> _loadGroup() async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) return;
    await context.read<GroupProvider>().selectGroup(authProvider.token!, widget.args.groupId);
  }

  Future<void> _refreshGroup() => _loadGroup();

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.watch<GroupProvider>();
    final selectedGroup = groupProvider.selectedGroup;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.args.groupName),
        actions: [
          IconButton(
            onPressed: selectedGroup == null
                ? null
                : () {
                    Navigator.of(context).pushNamed(
                      BalanceSummaryScreen.routeName,
                      arguments: BalanceSummaryArgs(groupId: selectedGroup.id, groupName: selectedGroup.name),
                    );
                  },
            icon: const Icon(Icons.balance),
            tooltip: 'Balances',
          ),
        ],
      ),
      floatingActionButton: selectedGroup == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).pushNamed(
                  AddExpenseScreen.routeName,
                  arguments: AddExpenseArgs(group: selectedGroup),
                );
                if (!mounted) return;
                await _loadGroup();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Expense'),
            ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshGroup();
        },
        child: Builder(
          builder: (_) {
            if (groupProvider.loading && selectedGroup == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (selectedGroup == null) {
              return ListView(
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('Unable to load group data. Pull to retry.')),
                ],
              );
            }
            if (selectedGroup.expenses.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('No expenses recorded yet.')),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: selectedGroup.expenses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final expense = selectedGroup.expenses[index];
                return _ExpenseCard(
                  groupId: selectedGroup.id,
                  expense: expense,
                  formatter: _currencyFormatter,
                  onUpdated: _loadGroup,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.groupId,
    required this.expense,
    required this.formatter,
    required this.onUpdated,
  });

  final String groupId;
  final Expense expense;
  final NumberFormat formatter;
  final Future<void> Function() onUpdated;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    expense.description,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleAction(context, value),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(formatter.format(expense.amount)),
            const SizedBox(height: 4),
            Text('Paid by ${expense.paidBy.name}'),
            const SizedBox(height: 8),
            Text(
              'Split among:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            for (final split in expense.splits)
              Text('${split.user.name} - ${formatter.format(split.amount)}'),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    final authProvider = context.read<AuthProvider>();
    final groupProvider = context.read<GroupProvider>();
    if (action == 'edit') {
      await Navigator.of(context).pushNamed(
        AddExpenseScreen.routeName,
        arguments: AddExpenseArgs(group: groupProvider.selectedGroup!, expense: expense),
      );
      await onUpdated();
      return;
    }
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Delete Expense'),
            content: const Text('Are you sure you want to delete this expense?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;
      try {
        await groupProvider.deleteExpense(authProvider.token!, groupId, expense.id);
        await onUpdated();
      } catch (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }
}
