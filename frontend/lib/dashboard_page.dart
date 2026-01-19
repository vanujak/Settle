import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:convert';
import 'login_page.dart';
import 'create_bill_page.dart';
import 'friends_page.dart';
import 'services/bill_service.dart';
import 'bill_details_page.dart';
import 'add_expense_page.dart';

class DashboardPage extends StatefulWidget {
  final String userName;
  final String token;

  const DashboardPage({super.key, required this.userName, required this.token});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  final _billService = BillService();
  List<dynamic> _myBills = [];
  bool _isLoadingBills = true;
  late IO.Socket socket;
  String? _currentUserId;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  @override
  void initState() {
    super.initState();
    _currentUserId = _getUserIdFromToken(widget.token);
    _fetchMyBills();
    _initSocket();
  }

  void _initSocket() {
    print('Initializing Dashboard Socket...');
    socket = IO.io('http://localhost:5000', IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .build()
    );

    socket.connect();

    socket.onConnect((_) {
      print('Dashboard Socket connected: ${socket.id}');
      final userId = _getUserIdFromToken(widget.token);
      print('Dashboard Joining Room for User ID: $userId');
      if (userId != null) {
        socket.emit('join_user', userId);
      } else {
        print('Error: Could not extract User ID from token, cannot join room.');
      }
    });

    socket.onDisconnect((_) => print('Dashboard Socket disconnected'));
    socket.onConnectError((data) => print('Dashboard Socket connection error: $data'));

    socket.on('bill_refresh', (_) {
      print('Dashboard: Received bill_refresh event via Socket!');
      _fetchMyBills();
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

  Future<void> _fetchMyBills() async {
    try {
      final bills = await _billService.getMyBillSplits(widget.token);
      if (mounted) {
        setState(() {
          _myBills = bills;
          _isLoadingBills = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingBills = false);
        // print('Error fetching bills: $e');
      }
    }
  }

  @override
  void dispose() {
    socket.disconnect();
    super.dispose();
  }

  Future<void> _confirmDeleteBill(String billId, String billName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF203A43),
        title: const Text('Delete Group', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete "$billName"?\nThis cannot be undone.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Optimistically UI update or wait for reload?
      // Let's just show loading
      if (mounted) setState(() => _isLoadingBills = true);
      try {
        await _billService.deleteBillSplit(widget.token, billId);
        // Explicitly fetch to ensure UI updates immediately and stops loading
        await _fetchMyBills();
      } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
          );
          _fetchMyBills(); // Reset loading if error
        }
      }
    }
  }

  Widget _buildHomeContent() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 40,
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const LoginPage(),
                    ),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            '${_getGreeting()},',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 24,
              fontWeight: FontWeight.w300,
            ),
          ),
          Text(
            widget.userName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Your Groups',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoadingBills
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _myBills.isEmpty
                    ? Center(
                        child: Text(
                          'No active bill splits.\nCreate one to get started!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withOpacity(0.5)),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchMyBills,
                        color: const Color(0xFF4CA1AF),
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _myBills.length,
                          itemBuilder: (context, index) {
                            final bill = _myBills[index];
                            return Card(
                              color: Colors.white.withOpacity(0.1),
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: CircleAvatar(
                                        backgroundColor: const Color(0xFF4CA1AF),
                                        child: const Icon(Icons.receipt, color: Colors.white),
                                      ),
                                      title: Text(
                                        bill['name'],
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                        '${bill['members'].length} members • Created by ${(_currentUserId != null && bill['createdBy']['_id'] == _currentUserId) ? 'Me' : bill['createdBy']['username']}',
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                      trailing: (_currentUserId != null && bill['createdBy']['_id'] == _currentUserId)
                                          ? IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                              onPressed: () => _confirmDeleteBill(bill['_id'], bill['name']),
                                            )
                                          : null,
                                      onTap: () {
                                         Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => BillDetailsPage(
                                              token: widget.token,
                                              billId: bill['_id'],
                                              billName: bill['name'],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const Divider(color: Colors.white24),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => BillDetailsPage(
                                                  token: widget.token,
                                                  billId: bill['_id'],
                                                  billName: bill['name'],
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.visibility, size: 18, color: Colors.white70),
                                          label: const Text('Summary', style: TextStyle(color: Colors.white)),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => AddExpensePage(
                                                  token: widget.token,
                                                  billId: bill['_id'],
                                                  billName: bill['name'],
                                                  members: bill['members'],
                                                ),
                                              ),
                                            ).then((value) {
                                              if (value == true) {
                                                // If expense added, maybe refresh? 
                                                // Socket will handle refresh usually, but good to know.
                                              }
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF4CA1AF),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.add, size: 18),
                                          label: const Text('Add Expense'),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomeContent(),
      CreateBillPage(token: widget.token),
      FriendsPage(token: widget.token),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F2027), // Deep Dark Blue/Black
              Color(0xFF203A43), // Deep Teal
              Color(0xFF2C5364), // Teal Grey
            ],
          ),
        ),
        child: SafeArea(
          child: pages[_selectedIndex],
        ),
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: const Color(0xFF203A43), // Bottom nav background
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
            if (index == 0) {
              _fetchMyBills();
            }
          },
          backgroundColor: const Color(0xFF203A43),
          selectedItemColor: const Color(0xFF4CA1AF),
          unselectedItemColor: Colors.white54,
          showUnselectedLabels: false,
          elevation: 10,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline, size: 32),
              activeIcon: Icon(Icons.add_circle, size: 32),
              label: 'Create',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_alt_outlined),
              label: 'Friends',
            ),
          ],
        ),
      ),
    );
  }
}
