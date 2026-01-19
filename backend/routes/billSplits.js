const express = require('express');
const router = express.Router();
const BillSplit = require('../models/BillSplit');
const User = require('../models/User');
const jwt = require('jsonwebtoken');

// Middleware to protect routes (Reuse or import if centralized, duplicating for now to ensure isolation)
const protect = async (req, res, next) => {
    let token;
    if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
        try {
            token = req.headers.authorization.split(' ')[1];
            const decoded = jwt.verify(token, process.env.JWT_SECRET);
            req.user = await User.findById(decoded.id).select('-password');
            if (!req.user) {
                return res.status(401).json({ message: 'User not found' });
            }
            next();
        } catch (error) {
            console.error(error);
            res.status(401).json({ message: 'Not authorized, token failed' });
        }
    }
    if (!token) {
        res.status(401).json({ message: 'Not authorized, no token' });
    }
};

// @desc    Create a new bill split group
// @route   POST /api/bills/create
// @access  Private
router.post('/create', protect, async (req, res) => {
    const { name, friendIds } = req.body;

    console.log('Creating Group:', name);
    console.log('Creator:', req.user._id);
    console.log('Friend IDs:', friendIds);

    if (!name || !friendIds || friendIds.length === 0) {
        return res.status(400).json({ message: 'Please provide a group name and select at least one friend.' });
    }

    try {
        // Members = Creator + Selected Friends
        // Explicitly ensuring req.user._id is included properly
        const members = [req.user._id.toString(), ...friendIds];

        console.log('Final Members Array:', members);

        const billSplit = await BillSplit.create({
            name,
            createdBy: req.user._id,
            members: members
        });

        // Populate members to get names for the socket event
        const populatedBill = await BillSplit.findById(billSplit._id).populate('members', 'firstName lastName username');

        // Emit socket event to all members
        if (req.io) {
            members.forEach(memberId => {
                req.io.to(memberId.toString()).emit('bill_refresh');
                console.log(`Socket: Emitted bill_refresh to ${memberId}`);
            });
        }

        res.status(201).json(populatedBill);
    } catch (error) {
        console.error('Create Bill Error:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// @desc    Get user's bill splits
// @route   GET /api/bills/my
// @access  Private
router.get('/my', protect, async (req, res) => {
    try {
        const bills = await BillSplit.find({ members: req.user._id })
            .populate('members', 'firstName lastName username')
            .populate('createdBy', 'firstName lastName username')
            .sort({ createdAt: -1 });
        res.json(bills);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// @desc    Get specific bill details with calculated settlements
// @route   GET /api/bills/:id
// @access  Private
router.get('/:id', protect, async (req, res) => {
    try {
        const bill = await BillSplit.findById(req.params.id)
            .populate('members', 'firstName lastName username')
            .populate('createdBy', 'firstName lastName username')
            .populate('expenses.paidBy', 'firstName lastName username')
            .populate('expenses.splitAmong.user', 'firstName lastName username');

        if (!bill) {
            return res.status(404).json({ message: 'Bill split group not found' });
        }

        // Calculate Settlements
        const balances = {}; // { userId: netAmount }

        // Initialize balances
        bill.members.forEach(member => {
            balances[member._id.toString()] = 0;
        });

        bill.expenses.forEach(expense => {
            const payerId = expense.paidBy._id.toString();
            // Payer gets credit for the full amount they paid
            if (balances[payerId] !== undefined) {
                balances[payerId] += expense.amount;
            }

            // Deduct each person's specific share
            expense.splitAmong.forEach(split => {
                if (split.user) {
                    // split.user might be an ID if population failed, or an object if successful
                    const memberId = split.user._id ? split.user._id.toString() : split.user.toString();

                    // Handle legacy data (missing amount) -> Default to equal split
                    let splitAmount = split.amount;
                    if (splitAmount === undefined || splitAmount === null) {
                        splitAmount = expense.amount / expense.splitAmong.length;
                    }

                    if (balances[memberId] !== undefined) {
                        balances[memberId] -= splitAmount;
                    }
                }
            });
        });

        // Resolve Debts (Minimize transactions heuristic)
        const debtors = [];
        const creditors = [];

        Object.keys(balances).forEach(userId => {
            const net = balances[userId];
            if (net < -0.01) debtors.push({ userId, amount: -net }); // Convert to positive debt
            if (net > 0.01) creditors.push({ userId, amount: net });
        });

        // Simple settlement matching
        const settlements = [];
        let i = 0; // debtor index
        let j = 0; // creditor index

        while (i < debtors.length && j < creditors.length) {
            const debtor = debtors[i];
            const creditor = creditors[j];

            const amount = Math.min(debtor.amount, creditor.amount);

            // Find user objects for details
            const debtorUser = bill.members.find(m => m._id.toString() === debtor.userId);
            const creditorUser = bill.members.find(m => m._id.toString() === creditor.userId);

            if (debtorUser && creditorUser) {
                settlements.push({
                    from: debtorUser,
                    to: creditorUser,
                    amount: Number(amount.toFixed(2))
                });
            }

            // Update remaining amounts
            debtor.amount -= amount;
            creditor.amount -= amount;

            if (debtor.amount < 0.01) i++;
            if (creditor.amount < 0.01) j++;
        }

        res.json({ ...bill.toObject(), settlements });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// @desc    Add expense to bill
// @route   POST /api/bills/:id/expense
// @access  Private
router.post('/:id/expense', protect, async (req, res) => {
    console.log('--- ADD EXPENSE REQUEST START ---');
    console.log('Headers:', req.headers);
    console.log('Body:', JSON.stringify(req.body, null, 2));

    const { description, amount, splitAmong } = req.body;
    let { paidBy } = req.body;

    if (!description || !amount) {
        return res.status(400).json({ message: 'Description and amount are required' });
    }

    try {
        const bill = await BillSplit.findById(req.params.id);
        if (!bill) {
            return res.status(404).json({ message: 'Bill split group not found' });
        }

        if (!paidBy) paidBy = req.user._id;

        // Validation & Transformation
        let finalSplit = [];
        if (Array.isArray(splitAmong)) {
            finalSplit = splitAmong.map((item, index) => {
                if (typeof item === 'string') {
                    // Handle raw ID string case (fallback)
                    console.warn(`Item ${index} is string, auto-converting.`);
                    return {
                        user: item,
                        amount: Number(amount) / splitAmong.length
                    };
                } else if (typeof item === 'object' && item !== null) {
                    // Handle object case
                    // Ensure 'user' and 'amount' keys exist
                    // Frontend 'user' key maps to Schema 'user' key
                    if (!item.amount && item.amount !== 0) {
                        console.error(`Item ${index} missing amount:`, item);
                        throw new Error(`Split item for user ${item.user} is missing amount.`);
                    }
                    return {
                        user: item.user,
                        amount: Number(item.amount)
                    };
                }
                return item;
            });
        } else {
            // Fallback: Default to all members equal split if no splitAmong provided
            console.log('No valid splitAmong provided, defaulting to all members.');
            const share = Number(amount) / bill.members.length;
            finalSplit = bill.members.map(m => ({
                user: m,
                amount: share
            }));
        }

        console.log('Final Split Payload to Save:', JSON.stringify(finalSplit, null, 2));

        const newExpense = {
            description,
            amount: Number(amount),
            paidBy,
            splitAmong: finalSplit,
        };

        bill.expenses.push(newExpense);
        await bill.save();
        console.log('Expense Saved Successfully');

        // Emit update
        if (req.io) {
            bill.members.forEach(memberId => {
                req.io.to(memberId.toString()).emit('bill_refresh');
            });
        }

        res.json(bill);
    } catch (error) {
        console.error('Add Expense Error Stack:', error);
        res.status(500).json({ message: error.message || 'Server error' });
    }
});

// @desc    Delete a bill split group
// @route   DELETE /api/bills/:id
// @access  Private
router.delete('/:id', protect, async (req, res) => {
    try {
        const bill = await BillSplit.findById(req.params.id);

        if (!bill) {
            return res.status(404).json({ message: 'Bill split group not found' });
        }

        // Check if user is the creator
        if (bill.createdBy.toString() !== req.user._id.toString()) {
            return res.status(403).json({ message: 'Not authorized to delete this group' });
        }

        const members = bill.members; // Store members to emit event later
        console.log(`Deleting Bill ${req.params.id}. Notifying members:`, members);

        await BillSplit.findByIdAndDelete(req.params.id);

        // Emit update to all members so their dashboard removes the bill
        if (req.io) {
            members.forEach(memberId => {
                console.log(`Socket: Emitting bill_refresh to user ${memberId}`);
                req.io.to(memberId.toString()).emit('bill_refresh');
            });
        }

        res.json({ message: 'Bill split group removed' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

module.exports = router;
