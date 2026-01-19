import 'package:flutter/material.dart';
import 'services/friend_service.dart';
import 'services/bill_service.dart';

class CreateBillPage extends StatefulWidget {
  final String token;
  const CreateBillPage({super.key, required this.token});

  @override
  State<CreateBillPage> createState() => _CreateBillPageState();
}

class _CreateBillPageState extends State<CreateBillPage> {
  final _billNameController = TextEditingController();
  final _friendService = FriendService();
  final _billService = BillService();
  
  List<dynamic> _friends = [];
  final Set<String> _selectedFriendIds = {};
  bool _isLoading = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _fetchFriends();
  }

  Future<void> _fetchFriends() async {
    try {
      final friends = await _friendService.getFriends(widget.token);
      if (mounted) {
        setState(() {
          _friends = friends;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading friends: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _toggleFriendSelection(String friendId) {
    setState(() {
      if (_selectedFriendIds.contains(friendId)) {
        _selectedFriendIds.remove(friendId);
      } else {
        _selectedFriendIds.add(friendId);
      }
    });
  }

  Future<void> _createBill() async {
    final name = _billNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.orangeAccent),
                const SizedBox(width: 12),
                const Text('Please enter a group name', style: TextStyle(color: Colors.white)),
              ],
            ),
            backgroundColor: const Color(0xFF203A43),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Colors.orangeAccent, width: 1),
            ),
            margin: const EdgeInsets.all(16),
      ));
      return;
    }

    if (_selectedFriendIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.orangeAccent),
                const SizedBox(width: 12),
                const Text('Please select at least one friend', style: TextStyle(color: Colors.white)),
              ],
            ),
            backgroundColor: const Color(0xFF203A43),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Colors.orangeAccent, width: 1),
            ),
            margin: const EdgeInsets.all(16),
      ));
      return;
    }

    setState(() => _isCreating = true);

    try {
      await _billService.createBillSplit(widget.token, name, _selectedFriendIds.toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF4CA1AF)),
                const SizedBox(width: 12),
                const Text(
                  'Group Created Successfully!',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF203A43),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFF4CA1AF), width: 1),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
        _billNameController.clear();
        setState(() {
          _selectedFriendIds.clear();
          _isCreating = false;
        });
        // Optionally navigate to the newly created bill or dashboard
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.redAccent),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: ${e.toString()}', style: const TextStyle(color: Colors.white))),
              ],
            ),
            backgroundColor: const Color(0xFF203A43),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Colors.redAccent, width: 1),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _billNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create Split Group',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          // Bill Name Input
          TextField(
            controller: _billNameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Group Name (e.g., "Trip to Galle")',
              labelStyle: const TextStyle(color: Colors.white70),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white30),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFF4CA1AF)),
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.receipt_long, color: Colors.white54),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Add Friends',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          // Friends List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _friends.isEmpty
                    ? Center(
                        child: Text(
                          'You have no friends yet.\nGo to Friends tab to add some!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _friends.length,
                        itemBuilder: (context, index) {
                          final friend = _friends[index];
                          final isSelected = _selectedFriendIds.contains(friend['_id']);
                          return Card(
                            color: isSelected ? const Color(0xFF4CA1AF).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected ? const Color(0xFF4CA1AF) : Colors.transparent, 
                                width: 1
                              ),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isSelected ? const Color(0xFF4CA1AF) : Colors.grey.withValues(alpha: 0.3),
                                child: Text(
                                  friend['firstName'][0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                '${friend['firstName']} ${friend['lastName']}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                '@${friend['username']}',
                                style: const TextStyle(color: Colors.white54),
                              ),
                              trailing: Checkbox(
                                value: isSelected,
                                activeColor: const Color(0xFF4CA1AF),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                side: const BorderSide(color: Colors.white54),
                                onChanged: (bool? value) {
                                  _toggleFriendSelection(friend['_id']);
                                },
                              ),
                              onTap: () => _toggleFriendSelection(friend['_id']),
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isCreating ? null : _createBill,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CA1AF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isCreating
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Create Group',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
