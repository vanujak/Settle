import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:convert';
import 'services/bill_service.dart';
import 'add_expense_page.dart';

class BillDetailsPage extends StatefulWidget {
  final String token;
  final String billId;
  final String billName;

  const BillDetailsPage({
    super.key,
    required this.token,
    required this.billId,
    required this.billName,
  });

  @override
  State<BillDetailsPage> createState() => _BillDetailsPageState();
}

class _BillDetailsPageState extends State<BillDetailsPage> {
  final _billService = BillService();
  Map<String, dynamic>? _billDetails;
  bool _isLoading = true;
  late IO.Socket socket;

  @override
  void initState() {
    super.initState();
    _fetchBillDetails();
    _initSocket();
  }

  void _initSocket() {
    socket = IO.io('http://localhost:5000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      print('BillDetails Socket connected');
      final userId = _getUserIdFromToken(widget.token);
      if (userId != null) {
        socket.emit('join_user', userId);
      }
    });

    socket.on('bill_refresh', (_) {
      print('BillDetails: Received bill_refresh event');
      _fetchBillDetails();
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

  Future<void> _fetchBillDetails() async {
    try {
      final details = await _billService.getBillDetails(widget.token, widget.billId);
      if (mounted) {
        setState(() {
          _billDetails = details;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _navigateToAddExpense() async {
    if (_billDetails == null) return;
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddExpensePage(
          token: widget.token,
          billId: widget.billId,
          billName: widget.billName,
          members: _billDetails!['members'],
        ),
      ),
    );

    if (result == true) {
      _fetchBillDetails(); // Refresh after adding expense
    }
  }

  @override
  void dispose() {
    socket.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.billName), backgroundColor: const Color(0xFF203A43), foregroundColor: Colors.white),
        body: Container(
           color: const Color(0xFF0F2027),
           child: const Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }

    if (_billDetails == null) {
       return Scaffold(
        appBar: AppBar(title: Text(widget.billName), backgroundColor: const Color(0xFF203A43), foregroundColor: Colors.white),
        body: Container(
             color: const Color(0xFF0F2027),
             child: const Center(child: Text('Failed to load details', style: TextStyle(color: Colors.white))),
        ),
      );
    }

    final settlements = _billDetails!['settlements'] as List<dynamic>;
    final expenses = _billDetails!['expenses'] as List<dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.billName),
        backgroundColor: const Color(0xFF203A43),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchBillDetails,
          )
        ],
      ),
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F2027),
              Color(0xFF203A43),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Settlements Section
              const Text(
                'Settlements (Who owes who)',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              settlements.isEmpty
                  ? const Card(
                      color: Colors.white10,
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'All settled up! No debts.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: settlements.length,
                      itemBuilder: (context, index) {
                        final settlement = settlements[index];
                        return Card(
                          color: Colors.white.withValues(alpha: 0.1),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.monetization_on, color: Colors.greenAccent),
                            title: Text(
                              '${settlement['from']['firstName']} owes ${settlement['to']['firstName']}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            trailing: Text(
                              'Rs. ${settlement['amount']}',
                              style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                    ),

              const SizedBox(height: 32),
              
              // Expenses History Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   const Text(
                    'Recent Expenses',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: _navigateToAddExpense,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Expense'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CA1AF),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              expenses.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text(
                          'No expenses yet.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: expenses.length,
                      separatorBuilder: (context, index) => const Divider(color: Colors.white24),
                      itemBuilder: (context, index) {
                        // Show newest first
                        final expense = expenses[expenses.length - 1 - index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            expense['description'],
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Paid by ${expense['paidBy']['firstName']}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          trailing: Text(
                            'Rs. ${expense['amount']}',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddExpense,
        backgroundColor: const Color(0xFF4CA1AF),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
