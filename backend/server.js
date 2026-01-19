const express = require('express');
const dotenv = require('dotenv');
const cors = require('cors');
const mongoose = require('mongoose');

// Load env vars
dotenv.config();

const http = require('http');
const { Server } = require('socket.io');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});

// Middleware
app.use(cors());
app.use(express.json()); // Body parser

// Socket.io connection handler
io.on('connection', (socket) => {
    console.log('Socket: New client connected', socket.id);

    socket.on('join_user', (userId) => {
        if (userId) {
            socket.join(userId);
            console.log(`Socket: User ${userId} joined room ${userId}`);
        }
    });

    socket.on('disconnect', () => {
        // console.log('Socket: Client disconnected');
    });
});

// Make io accessible in routes
app.use((req, res, next) => {
    req.io = io;
    next();
});

// Connect to MongoDB
const connectDB = async () => {
    try {
        const conn = await mongoose.connect(process.env.MONGO_URI);
        console.log(`MongoDB Connected: ${conn.connection.host}`);
    } catch (error) {
        console.error(`Error: ${error.message}`);
        process.exit(1);
    }
};

connectDB();

// Routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/friends', require('./routes/friends'));

const PORT = process.env.PORT || 5000;

server.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
