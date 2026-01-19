const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const User = require('../models/User');

/**
 * Generate JWT token for user
 * @param {string} id - User ID
 * @returns {string} JWT token
 */
const generateToken = (id) => {
    return jwt.sign({ id }, process.env.JWT_SECRET, {
        expiresIn: '30d',
    });
};

// --------------------------------------------------
// @desc    Register a new user
// @route   POST /api/auth/signup
// @access  Public
// --------------------------------------------------
router.post('/signup', async (req, res) => {
    const { firstName, lastName, username, dob, gender, email, mobile, password } = req.body;

    try {
        // Check if user already exists (email, mobile, or username)
        const userExists = await User.findOne({
            $or: [{ email }, { mobile }, { username }]
        });

        if (userExists) {
            return res.status(400).json({
                message: 'User with this email, mobile, or username already exists'
            });
        }

        // Create new user
        const user = await User.create({
            firstName,
            lastName,
            username,
            dob,
            gender,
            email,
            mobile,
            password,
        });

        if (user) {
            return res.status(201).json({
                _id: user._id,
                username: user.username,
                firstName: user.firstName,
                email: user.email,
                token: generateToken(user._id),
            });
        } else {
            return res.status(400).json({ message: 'Invalid user data' });
        }
    } catch (error) {
        console.error('Signup Error:', error);
        return res.status(500).json({ message: 'Server error' });
    }
});

// --------------------------------------------------
// @desc    Authenticate user & get token
// @route   POST /api/auth/login
// @access  Public
// --------------------------------------------------
router.post('/login', async (req, res) => {
    const { email, password } = req.body;

    try {
        const user = await User.findOne({ email });

        if (user && (await user.matchPassword(password))) {
            return res.json({
                _id: user._id,
                username: user.username,
                firstName: user.firstName,
                email: user.email,
                token: generateToken(user._id),
            });
        } else {
            return res.status(401).json({ message: 'Invalid email or password' });
        }
    } catch (error) {
        console.error('Login Error:', error);
        return res.status(500).json({ message: 'Server error' });
    }
});

module.exports = router;
