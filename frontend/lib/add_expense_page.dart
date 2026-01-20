import 'package:flutter/material.dart';
import 'services/bill_service.dart';
import 'dart:convert';

class AddExpensePage extends StatefulWidget {
  final String token;
  final String billId;
  final String billName;
  final List<dynamic> members;

  const AddExpensePage({
    super.key,
    required this.token,
    required this.billId,
    required this.billName,
    required this.members,
  });

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _billService = BillService();
  bool _isLoading = false;
  
  // Split Logic
  bool _isWeightedSplit = false;
  final Set<String> _selectedMemberIds = {};
  final Map<String, TextEditingController> _percentageControllers = {};
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _getUserIdFromToken(widget.token);
    // Default to split among all members
    for (var member in widget.members) {
      _selectedMemberIds.add(member['_id']);
      // Initialize percentage controllers with default (even split optional, or empty)
      _percentageControllers[member['_id']] = TextEditingController(text: '0');
    }
    _recalculateEvenPercentages();
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
      return null;
    }
  }

  void _recalculateEvenPercentages() {
    if (_selectedMemberIds.isEmpty) return;
    final share = 100 / _selectedMemberIds.length;
    for (var id in _selectedMemberIds) {
      _percentageControllers[id]?.text = share.toStringAsFixed(1);
    }
  }

  void _toggleMemberSelection(String memberId) {
    setState(() {
      if (_selectedMemberIds.contains(memberId)) {
        _selectedMemberIds.remove(memberId);
      } else {
        _selectedMemberIds.add(memberId);
      }
      
      if (!_isWeightedSplit) {
        _recalculateEvenPercentages();
      }
    });
  }

  Future<void> _submitExpense() async {
    final description = _descriptionController.text.trim();
    final amountText = _amountController.text.trim();

    if (description.isEmpty || amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.orangeAccent),
                const SizedBox(width: 12),
                const Text('Please enter description and amount', style: TextStyle(color: Colors.white)),
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

    final totalAmount = double.tryParse(amountText);
    if (totalAmount == null || totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.orangeAccent),
                const SizedBox(width: 12),
                const Text('Please enter a valid amount', style: TextStyle(color: Colors.white)),
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

    if (_selectedMemberIds.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.orangeAccent),
                const SizedBox(width: 12),
                const Text('Please select at least one person', style: TextStyle(color: Colors.white)),
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

    List<Map<String, dynamic>> finalSplit = [];
    
    if (_isWeightedSplit) {
      double totalPercent = 0;
      for (var id in _selectedMemberIds) {
         final percent = double.tryParse(_percentageControllers[id]?.text ?? '0') ?? 0;
         totalPercent += percent;
      }
      
      // Allow small tolerance for floating point
      if ((totalPercent - 100).abs() > 0.5) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.orangeAccent),
                const SizedBox(width: 12),
                Expanded(child: Text('Percentages must sum to 100% (Current: ${totalPercent.toStringAsFixed(1)}%)', style: const TextStyle(color: Colors.white))),
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
      
       for (var id in _selectedMemberIds) {
         final percent = double.tryParse(_percentageControllers[id]?.text ?? '0') ?? 0;
         final shareAmount = totalAmount * (percent / 100);
         if (shareAmount > 0) {
            finalSplit.add({'user': id, 'amount': shareAmount});
         }
      }

    } else {
       // Equal split
       final shareAmount = totalAmount / _selectedMemberIds.length;
       for (var id in _selectedMemberIds) {
         finalSplit.add({'user': id, 'amount': shareAmount});
       }
    }

    setState(() => _isLoading = true);

    try {
      await _billService.addExpense(
        widget.token,
        widget.billId,
        description,
        totalAmount,
        finalSplit,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF4CA1AF)),
                const SizedBox(width: 12),
                const Text('Expense added successfully!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) {
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    for (var controller in _percentageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        backgroundColor: const Color(0xFF203A43),
        foregroundColor: Colors.white,
      ),
      body: Container(
        height: double.infinity,
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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text(
                'Group: ${widget.billName}',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _descriptionController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Description (e.g. Dinner)',
                  labelStyle: const TextStyle(color: Colors.white70),
                   enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF4CA1AF)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.description, color: Colors.white54),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                style: const TextStyle(color: Colors.white),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (Rs.)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF4CA1AF)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.attach_money, color: Colors.white54),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Split Details',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      const Text('Equally', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Switch(
                        value: _isWeightedSplit,
                        onChanged: (value) {
                          setState(() {
                            _isWeightedSplit = value;
                            if (!value) _recalculateEvenPercentages();
                          });
                        },
                        activeThumbColor: const Color(0xFF4CA1AF),
                      ),
                      const Text('Weighted (%)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.members.length,
                  itemBuilder: (context, index) {
                    final member = widget.members[index];
                    final memberId = member['_id'];
                    final isSelected = _selectedMemberIds.contains(memberId);
                    
                    return Card(
                      color: isSelected ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isSelected,
                              activeColor: const Color(0xFF4CA1AF),
                              checkColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              onChanged: (bool? value) {
                                _toggleMemberSelection(memberId);
                              },
                            ),
                            CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFF4CA1AF),
                                child: Text(
                                    member['firstName'][0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text(
                                    member['_id'] == _currentUserId ? 'Me' : '${member['firstName']} ${member['lastName']}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    '@${member['username']}',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            if (_isWeightedSplit && isSelected)
                              SizedBox(
                                width: 70,
                                child: TextField(
                                  controller: _percentageControllers[memberId],
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    suffixText: '%',
                                    suffixStyle: const TextStyle(color: Colors.white70),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: Colors.white30),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: Color(0xFF4CA1AF)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitExpense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CA1AF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Add Expense',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
