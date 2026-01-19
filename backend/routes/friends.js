const express = require('express');
const router = express.Router();
const User = require('../models/User');
const jwt = require('jsonwebtoken');

/**
 * Middleware: Protect routes using JWT authentication
 * - Expects token in Authorization header as: Bearer <token>
 * - Attaches user object to req.user (excluding password)
 */
const protect = async (req, res, next) => {
    let token;

    // Check for Bearer token in Authorization header
    if (
        req.headers.authorization &&
        req.headers.authorization.startsWith('Bearer')
    ) {
        try {
            token = req.headers.authorization.split(' ')[1];

            // Verify JWT token
            const decoded = jwt.verify(token, process.env.JWT_SECRET);

            // Fetch authenticated user
            req.user = await User.findById(decoded.id).select('-password');

            if (!req.user) {
                return res.status(401).json({ message: 'User not found' });
            }

            next();
            return;
        } catch (error) {
            console.error('Auth Middleware Error:', error);
            return res
                .status(401)
                .json({ message: 'Not authorized, token failed' });
        }
    }

    // No token provided
    if (!token) {
        return res
            .status(401)
            .json({ message: 'Not authorized, no token' });
    }
};

// --------------------------------------------------
// @desc    Add a friend by username
// @route   POST /api/friends/add
// @access  Private
// --------------------------------------------------
router.post('/add', protect, async (req, res) => {
    const { username } = req.body;

    console.log(
        `Adding friend for user ${req.user.username}: adding ${username}`
    );

    try {
        const user = await User.findById(req.user._id);

        // Ensure friends array exists
        if (!user.friends) {
            user.friends = [];
        }

        const friend = await User.findOne({ username });

        if (!friend) {
            console.log('Friend user not found');
            return res.status(404).json({ message: 'User not found' });
        }

        // Prevent adding yourself as a friend
        if (user.username === username) {
            return res
                .status(400)
                .json({ message: 'You cannot add yourself as a friend' });
        }

        // Check if friend already exists (safe string comparison)
        const isAlreadyFriend = user.friends.some(
            (friendId) => friendId.toString() === friend._id.toString()
        );

        if (isAlreadyFriend) {
            return res
                .status(400)
                .json({ message: 'User is already your friend' });
        }

        // Add friend to user's friend list (atomic operation)
        await User.findByIdAndUpdate(user._id, {
            $addToSet: { friends: friend._id },
        });

        // Mutual add: add user to friend's friend list
        await User.findByIdAndUpdate(friend._id, {
            $addToSet: { friends: user._id },
        });

        console.log(
            `Friendship created between ${user.username} and ${friend.username}`
        );

        // Notify friend via socket if available
        if (req.io) {
            req.io
                .to(friend._id.toString())
                .emit('friends_refresh');

            console.log(
                `Socket: Emitted friends_refresh to ${friend.username} (${friend._id})`
            );
        } else {
            console.warn('Socket: req.io is undefined');
        }

        return res.status(200).json({
            message: 'Friend added successfully',
            friend: {
                _id: friend._id,
                username: friend.username,
                firstName: friend.firstName,
                lastName: friend.lastName,
            },
        });
    } catch (error) {
        console.error('Add Friend Error:', error);
        return res
            .status(500)
            .json({ message: error.message || 'Server error' });
    }
});

// --------------------------------------------------
// @desc    Get all friends
// @route   GET /api/friends
// @access  Private
// --------------------------------------------------
router.get('/', protect, async (req, res) => {
    try {
        const user = await User.findById(req.user._id).populate(
            'friends',
            'firstName lastName username email mobile'
        );

        return res.json(user.friends);
    } catch (error) {
        console.error('Get Friends Error:', error);
        return res.status(500).json({ message: 'Server error' });
    }
});

// --------------------------------------------------
// @desc    Remove a friend
// @route   POST /api/friends/remove
// @access  Private
// --------------------------------------------------
router.post('/remove', protect, async (req, res) => {
    const { friendId } = req.body;

    try {
        // Remove friend from current user's list
        await User.findByIdAndUpdate(req.user._id, {
            $pull: { friends: friendId },
        });

        // Mutual remove: remove current user from friend's list
        await User.findByIdAndUpdate(friendId, {
            $pull: { friends: req.user._id },
        });

        // Notify friend via socket
        if (req.io) {
            req.io.to(friendId).emit('friends_refresh');
        }

        return res.json({ message: 'Friend removed' });
    } catch (error) {
        console.error('Remove Friend Error:', error);
        return res.status(500).json({ message: 'Server error' });
    }
});

module.exports = router;
