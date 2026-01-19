const express = require('express');
const router = express.Router();
const BillSplit = require('../models/BillSplit');
const User = require('../models/User');
const jwt = require('jsonwebtoken');

/**
 * Middleware: Protect routes using JWT authentication
 * - Expects token in Authorization header as: Bearer <token>
 * - Attaches user object to req.user (excluding password)
 */
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

            return next();
        } catch (error) {
            console.error('Auth Middleware Error:', error);
            return res.status(401).json({ message: 'Not authorized, token failed' });
        }
    }

    if (!token) {
        return res.status(401).json({ message: 'Not authorized, no token' });
    }
};

// --------------------------------------------------
// @desc    Create a new bill split group
// @route   POST /api/bills/create
// @access  Private
// --------------------------------------------------
router.post('/create', protect, async (req, res) => {
    const { name, friendIds } = req.body;

    console.log('Creating Bill Split Group:', name);
    console.log('Creator ID:', req.user._id);
    console.log('Friend IDs:', friendIds);

    if (!name || !friendIds || friendIds.length === 0) {
        return res.status(400).json({
            message: 'Please provide a group name and select at least one friend.'
        });
    }

    try {
        // Members = creator + selected friends
        const members = [req.user._id.toString(), ...friendIds];
        console.log('Final Members Array:', members);

        const billSplit = await BillSplit.create({
            name,
            createdBy: req.user._id,
            members
        });

        // Populate members for socket emission
        const populatedBill = await BillSplit.findById(billSplit._id).populate(
            'members',
            'firstName lastName username'
        );

        // Emit socket event to all members
        if (req.io) {
            members.forEach(memberId => {
                req.io.to(memberId.toString()).emit('bill_refresh');
                console.log(`Socket: Emitted bill_refresh to ${memberId}`);
            });
        }

        return res.status(201).json(populatedBill);
    } catch (error) {
        console.error('Create Bill Error:', error);
        return res.status(500).json({ message: 'Server error' });
    }
});

// --------------------------------------------------
// @desc    Get user's bill splits
// @route   GET /api/bills/my
// @access  Private
// --------------------------------------------------
router.get('/my', protect, async (req, res) => {
    try {
        const bills = await BillSplit.find({ members: req.user._id })
            .populate('members', 'firstName lastName username')
            .populate('createdBy', 'firstName lastName username')
            .sort({ createdAt: -1 });

        return res.json(bills);
    } catch (error) {
        console.error('Get My Bills Error:', error);
        return res.status(500).json({ message: 'Server error' });
    }
});

// --------------------------------------------------
// @desc    Get specific bill details with settlements
// @route   GET /api/bills/:id
// @access  Private
// --------------------------------------------------
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

        // Calculate net balances
        const balances = {};
        bill.members.forEach(member => {
            balances[member._id.toString()] = 0;
        });

        bill.expenses.forEach(expense => {
            const payerId = expense.paidBy._id.toString();
            if (balances[payerId] !== undefined) balances[payerId] += expense.amount;

            expense.splitAmong.forEach(split => {
                if (split.user) {
                    const memberId = split.user._id
                        ? split.user._id.toString()
                        : split.user.toString();

                    let splitAmount = split.amount;
                    if (splitAmount === undefined || splitAmount === null) {
                        splitAmount = expense.amount / expense.splitAmong.length;
                    }

                    if (balances[memberId] !== undefined) balances[memberId] -= splitAmount;
                }
            });
        });

        // Resolve settlements
        const debtors = [];
        const creditors = [];

        Object.keys(balances).forEach(userId => {
            const net = balances[userId];
            if (net < -0.01) debtors.push({ userId, amount: -net });
            if (net > 0.01) creditors.push({ userId, amount: net });
        });

        const settlements = [];
        let i = 0, j = 0;

        while (i < debtors.length && j < creditors.length) {
            const debtor = debtors[i];
            const creditor = creditors[j];
            const amount = Math.min(debtor.amount, creditor.amount);

            const debtorUser = bill.members.find(m => m._id.toString() === debtor.userId);
            const creditorUser = bill.members.find(m => m._id.toString() === creditor.userId);

            if (debtorUser && creditorUser) {
                settlements.push({
                    from: debtorUser,
                    to: creditorUser,
                    amount: Number(amount.toFixed(2))
                });
            }

            debtor.amount -= amount;
            creditor.amount -= amount;

            if (debtor.amount < 0.01) i++;
            if (creditor.amount < 0.01) j++;
        }

        return res.json({ ...bill.toObject(), settlements });
    } catch (error) {
        console.error('Get Bill Details Error:', error);
        return res.status(500).json({ message: 'Server error' });
    }
});

// --------------------------------------------------
// @desc    Add expense to a bill
// @route   POST /api/bills/:id/expense
// @access  Private
// --------------------------------------------------
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
        if (!bill) return res.status(404).json({ message: 'Bill split group not found' });

        if (!paidBy) paidBy = req.user._id;

        // Transform splitAmong to final payload
        let finalSplit = [];
        if (Array.isArray(splitAmong)) {
            finalSplit = splitAmong.map((item, index) => {
                if (typeof item === 'string') {
                    return { user: item, amount: Number(amount) / splitAmong.length };
                } else if (item && typeof item === 'object') {
                    if (!item.amount && item.amount !== 0) {
                        throw new Error(`Split item for user ${item.user} missing amount.`);
                    }
                    return { user: item.user, amount: Number(item.amount) };
                }
                return item;
            });
        } else {
            const share = Number(amount) / bill.members.length;
            finalSplit = bill.members.map(m => ({ user: m, amount: share }));
        }

        console.log('Final Split Payload:', JSON.stringify(finalSplit, null, 2));

        const newExpense = { description, amount: Number(amount), paidBy, splitAmong: finalSplit };

        bill.expenses.push(newExpense);
        await bill.save();
        console.log('Expense saved successfully');

        // Emit update to members
        if (req.io) {
            bill.members.forEach(memberId => req.io.to(memberId.toString()).emit('bill_refresh'));
        }

        return res.json(bill);
    } catch (error) {
        console.error('Add Expense Error:', error);
        return res.status(500).json({ message: error.message || 'Server error' });
    }
});

// --------------------------------------------------
// @desc    Delete a bill split group
// @route   DELETE /api/bills/:id
// @access  Private
// --------------------------------------------------
router.delete('/:id', protect, async (req, res) => {
    try {
        const bill = await BillSplit.findById(req.params.id);
        if (!bill) return res.status(404).json({ message: 'Bill split group not found' });

        // Only creator can delete
        if (bill.createdBy.toString() !== req.user._id.toString()) {
            return res.status(403).json({ message: 'Not authorized to delete this group' });
        }

        const members = bill.members;
        console.log(`Deleting Bill ${req.params.id}, notifying members:`, members);

        await BillSplit.findByIdAndDelete(req.params.id);

        if (req.io) {
            members.forEach(memberId => req.io.to(memberId.toString()).emit('bill_refresh'));
        }

        return res.json({ message: 'Bill split group removed' });
    } catch (error) {
        console.error('Delete Bill Error:', error);
        return res.status(500).json({ message: 'Server error' });
    }
});

// --------------------------------------------------
// @desc    Delete an expense from a bill
// @route   DELETE /api/bills/:id/expense/:expenseId
// @access  Private
// --------------------------------------------------
router.delete('/:id/expense/:expenseId', protect, async (req, res) => {
    try {
        const bill = await BillSplit.findById(req.params.id);
        if (!bill) return res.status(404).json({ message: 'Bill split group not found' });

        const expense = bill.expenses.id(req.params.expenseId);
        if (!expense) return res.status(404).json({ message: 'Expense not found' });

        if (expense.paidBy.toString() !== req.user._id.toString()) {
            return res.status(401).json({ message: 'Not authorized to delete this expense' });
        }

        bill.expenses.pull(req.params.expenseId);
        await bill.save();

        if (req.io) {
            bill.members.forEach(memberId => req.io.to(memberId.toString()).emit('bill_refresh'));
        }

        return res.json({ message: 'Expense removed' });
    } catch (error) {
        console.error('Delete Expense Error:', error);
        return res.status(500).json({ message: 'Server error' });
    }
});

module.exports = router;
