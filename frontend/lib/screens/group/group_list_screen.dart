import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/group.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../auth/login_screen.dart';
import '../auth/login_screen.dart';
import 'group_detail_screen.dart';

class GroupListScreen extends StatefulWidget {
  const GroupListScreen({super.key});

  static const routeName = '/groups';

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  bool _initialLoadDone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialLoadDone) {
      _initialLoadDone = true;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) return;
    await context.read<GroupProvider>().loadGroups(authProvider.token!);
  }

  Future<void> _showCreateGroupDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final membersController = TextEditingController();
    final authProvider = context.read<AuthProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Group'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Group Name'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter group name';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description (optional)'),
                  ),
                  TextFormField(
                    controller: membersController,
                    decoration: const InputDecoration(
                      labelText: 'Member IDs (comma separated)',
                      helperText: 'Include your own ID to join this group',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    final members = membersController.text
        .split(',')
        .map((e) => e.trim())
        .where((element) => element.isNotEmpty)
        .map((id) => AppUser(id: id, name: '', email: ''))
        .toList();

    try {
      await context.read<GroupProvider>().createGroup(
            authProvider.token!,
            name: nameController.text.trim(),
            description: descriptionController.text.trim().isEmpty
                ? null
                : descriptionController.text.trim(),
            members: members,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group created successfully')),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final groupProvider = context.watch<GroupProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Groups'),
        actions: [
          IconButton(
            onPressed: () async {
              await authProvider.logout();
              if (!mounted) return;
                Navigator.of(context)
                  .pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateGroupDialog,
        label: const Text('New Group'),
        icon: const Icon(Icons.group_add),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Builder(
          builder: (_) {
            if (groupProvider.loading && groupProvider.groups.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (groupProvider.groups.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('No groups yet. Pull to refresh.')),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: groupProvider.groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final group = groupProvider.groups[index];
                return _GroupTile(group: group);
              },
            );
          },
        ),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(group.name),
        subtitle: Text(group.description ?? 'No description'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).pushNamed(
            GroupDetailScreen.routeName,
            arguments: GroupDetailArgs(groupId: group.id, groupName: group.name),
          );
        },
      ),
    );
  }
}
