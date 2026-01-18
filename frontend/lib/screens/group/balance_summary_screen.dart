import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';

class BalanceSummaryArgs {
  const BalanceSummaryArgs({required this.groupId, required this.groupName});

  final String groupId;
  final String groupName;
}

class BalanceSummaryScreen extends StatefulWidget {
  const BalanceSummaryScreen({super.key, required this.args});

  static const routeName = '/groups/balances';

  final BalanceSummaryArgs args;

  @override
  State<BalanceSummaryScreen> createState() => _BalanceSummaryScreenState();
}

class _BalanceSummaryScreenState extends State<BalanceSummaryScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadBalances();
    }
  }

  Future<void> _loadBalances() async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) return;
    await context.read<GroupProvider>().fetchBalances(authProvider.token!, widget.args.groupId);
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.watch<GroupProvider>();

    return Scaffold(
      appBar: AppBar(title: Text('${widget.args.groupName} Balances')),
      body: RefreshIndicator(
        onRefresh: _loadBalances,
        child: Builder(
          builder: (_) {
            if (groupProvider.loading && groupProvider.balances.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (groupProvider.balances.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('No balances calculated yet.')), 
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: groupProvider.balances.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final balance = groupProvider.balances[index];
                final fromUser = balance['fromUser'] as Map<String, dynamic>;
                final toUser = balance['toUser'] as Map<String, dynamic>;
                final amount = balance['amount'] as num;
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.swap_horiz),
                    title: Text('${fromUser['name']} owes ${toUser['name']}'),
                    subtitle: Text('Amount: ${amount.toStringAsFixed(2)}'),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
