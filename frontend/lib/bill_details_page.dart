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
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _getUserIdFromToken(widget.token);
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

  Future<void> _confirmDeleteExpense(String expenseId, String description) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF203A43),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF4CA1AF), width: 1)
        ),
        title: const Text('Delete Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Delete "$description"?\nThis will recalculate all settlements.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed == true) {
       if (mounted) setState(() => _isLoading = true);
       try {
         await _billService.deleteExpense(widget.token, widget.billId, expenseId);
         await _fetchBillDetails(); 
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF4CA1AF)),
                    const SizedBox(width: 12),
                    const Text('Expense deleted', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
         }
       } catch (e) {
         if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.redAccent),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
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
                        final isPayer = _currentUserId != null && expense['paidBy']['_id'] == _currentUserId;

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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Rs. ${expense['amount']}',
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              if (isPayer) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.white54, size: 20),
                                  onPressed: () => _confirmDeleteExpense(expense['_id'], expense['description']),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ],
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
