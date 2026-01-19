const mongoose = require('mongoose');

const billSplitSchema = new mongoose.Schema({
    name: {
        type: String,
        required: true,
        trim: true
    },
    createdBy: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    members: [{
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User'
    }],
    expenses: [{
        description: { type: String, required: true },
        amount: { type: Number, required: true },
        paidBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
        splitAmong: [{
            user: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
            amount: { type: Number }
        }],
        createdAt: { type: Date, default: Date.now }
    }],
    createdAt: {
        type: Date,
        default: Date.now
    }
});

module.exports = mongoose.model('BillSplit', billSplitSchema);
