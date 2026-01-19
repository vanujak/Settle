const express = require('express');
const router = express.Router();
const User = require('../models/User');
const jwt = require('jsonwebtoken');

// Middleware to protect routes
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
            return;
        } catch (error) {
            console.error('Auth Middleware Error:', error);
            res.status(401).json({ message: 'Not authorized, token failed' });
        }
    }

    if (!token) {
        res.status(401).json({ message: 'Not authorized, no token' });
    }
};

// @desc    Add a friend by username
// @route   POST /api/friends/add
// @access  Private
router.post('/add', protect, async (req, res) => {
    const { username } = req.body;
    console.log(`Adding friend for user ${req.user.username}: adding ${username}`);

    try {
        const user = await User.findById(req.user._id);
        if (!user.friends) {
            user.friends = [];
        }

        const friend = await User.findOne({ username });

        if (!friend) {
            console.log('Friend user not found');
            return res.status(404).json({ message: 'User not found' });
        }

        if (user.username === username) {
            return res.status(400).json({ message: 'You cannot add yourself as a friend' });
        }

        // Safe comparison using strings
        const isAlreadyFriend = user.friends.some(friendId =>
            friendId.toString() === friend._id.toString()
        );

        if (isAlreadyFriend) {
            return res.status(400).json({ message: 'User is already your friend' });
        }

        user.friends.push(friend._id);
        await user.save();

        console.log('Friend added successfully');
        res.status(200).json({
            message: 'Friend added successfully', friend: {
                _id: friend._id,
                username: friend.username,
                firstName: friend.firstName,
                lastName: friend.lastName
            }
        });
    } catch (error) {
        console.error('Add Friend Error:', error);
        res.status(500).json({ message: error.message || 'Server error' });
    }
});

// @desc    Get all friends
// @route   GET /api/friends
// @access  Private
router.get('/', protect, async (req, res) => {
    try {
        const user = await User.findById(req.user._id).populate('friends', 'firstName lastName username email mobile');
        res.json(user.friends);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

// @desc    Remove a friend
// @route   POST /api/friends/remove
// @access  Private
router.post('/remove', protect, async (req, res) => {
    const { friendId } = req.body;

    try {
        const user = await User.findById(req.user._id);
        if (user.friends) {
            user.friends = user.friends.filter(id => id.toString() !== friendId);
            await user.save();
        }

        res.json({ message: 'Friend removed' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
});

module.exports = router;
