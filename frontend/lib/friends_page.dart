import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'services/friend_service.dart';

class FriendsPage extends StatefulWidget {
  final String token;
  const FriendsPage({super.key, required this.token});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final _friendService = FriendService();
  List<dynamic> _friends = [];
  bool _isLoading = true;
  final _usernameController = TextEditingController();
  late IO.Socket socket;

  @override
  void initState() {
    super.initState();
    _fetchFriends();
    _initSocket();
  }

  void _initSocket() {
    socket = IO.io('http://localhost:5000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      print('Socket connected');
      final userId = _getUserIdFromToken(widget.token);
      if (userId != null) {
        socket.emit('join_user', userId);
      }
    });

    socket.on('friends_refresh', (_) {
      print('Received friends_refresh event');
      _fetchFriends();
    });
  }

  String? _getUserIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = base64Url.normalize(parts[1]);
      final resp = utf8.decode(base64Url.decode(payload));
      final payloadMap = jsonDecode(resp);
      return payloadMap['id'];
    } catch (e) {
      print('Error decoding token: $e');
      return null;
    }
  }

  @override
  void dispose() {
    socket.disconnect();
    _usernameController.dispose();
    super.dispose();
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
        // Suppress error snackbar on auto-refresh to avoid annoyance
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error loading friends: ${e.toString()}'), backgroundColor: Colors.red),
        // );
      }
    }
  }

  Future<void> _addFriend() async {
    if (_usernameController.text.isEmpty) return;

    try {
      await _friendService.addFriend(widget.token, _usernameController.text);
      if (mounted) {
        _usernameController.clear();
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend added successfully!')),
        );
        _fetchFriends(); // Refresh list immediately for the initiator
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeFriend(String friendId) async {
    try {
      await _friendService.removeFriend(widget.token, friendId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend removed')),
        );
        _fetchFriends(); // Refresh list immediately for the initiator
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddFriendDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF203A43),
        title: const Text('Add Friend', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _usernameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter username',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: _addFriend,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CA1AF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Friends',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                   IconButton(
                    onPressed: _fetchFriends,
                    icon: const Icon(Icons.refresh, color: Colors.white, size: 28),
                    tooltip: 'Refresh List',
                  ),
                  IconButton(
                    onPressed: _showAddFriendDialog,
                    icon: const Icon(Icons.person_add, color: Colors.white, size: 28),
                    tooltip: 'Add Friend',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _friends.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 60, color: Colors.white.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text(
                          'No friends yet.\nAdd one to start splitting bills!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _friends.length,
                    itemBuilder: (context, index) {
                      final friend = _friends[index];
                      return Card(
                        color: Colors.white.withValues(alpha: 0.1),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF4CA1AF),
                            child: Text(
                              friend['firstName'][0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            '${friend['firstName']} ${friend['lastName']}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '@${friend['username']}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.person_remove_outlined, color: Colors.white54),
                            onPressed: () => _removeFriend(friend['_id']),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
