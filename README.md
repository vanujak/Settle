# Settle - Smart Bill Splitting App

**Settle** is a premium, real-time bill splitting application designed to make sharing expenses with friends and family effortless. Whether it's a group trip, a shared dinner, or household expenses, Settle calculates who owes whom in seconds, minimizing the number of transactions needed.

## 🚀 Features

-   **Group Management**: Create groups for trips, events, or shared living.
-   **Smart Settlements**: Our algorithm automatically calculates the most efficient way to settle debts using a minimum transaction strategy.
-   **Real-Time Updates**: Built with **Socket.io**, all changes (new expenses, settlements, deletions) appear instantly on all members' devices without refreshing.
-   **Flexible Splitting**: Support for **Equal** splits and **Weighted** (percentage-based) splits.
-   **Friend System**: Add friends by username and easily add them to multiple groups.
-   **Secure Authentication**: JWT-based login and signup system.
-   **Premium UI**: A sleek, modern dark-themed interface with glassmorphism elements.

## 🛠️ Tech Stack

### Frontend
-   **Framework**: [Flutter](https://flutter.dev/) (Dart)
-   **Platforms**: Android, iOS, Web
-   **State Management**: `setState` (Clean & Simple)
-   **Networking**: `http` package
-   **Real-time**: `socket_io_client`

### Backend
-   **Runtime**: [Node.js](https://nodejs.org/)
-   **Framework**: [Express.js](https://expressjs.com/)
-   **Database**: [MongoDB](https://www.mongodb.com/) (Mongoose ODM)
-   **Authentication**: JSON Web Tokens (JWT)
-   **Real-time**: `socket.io`

## 📦 Installation & Setup

### Prerequisites
-   Node.js & npm installed
-   Flutter SDK installed
-   MongoDB instance (Local or Atlas URL)

### 1. Backend Setup
Navigate to the backend directory:
```bash
cd backend
```

Install dependencies:
```bash
npm install
```

Create a `.env` file in the `backend` folder and add your configuration:
```env
PORT=5000
MONGO_URI=your_mongodb_connection_string
JWT_SECRET=your_jwt_secret_key
```

Run the server:
```bash
# Development mode
npm run dev

# Or standard start
node server.js
```
The server will start on `http://localhost:5000`.

### 2. Frontend Setup
Navigate to the frontend directory:
```bash
cd frontend
```

Get Flutter dependencies:
```bash
flutter pub get
```

Run the app:
```bash
# For Chrome (Web)
flutter run -d chrome

# For Mobile (Emulator/Device)
flutter run
```

## 📱 Usage Guide

1.  **Sign Up**: Create an account with your details.
2.  **Add Friends**: Go to the "Friends" tab and add users by their unique username.
3.  **Create a Group**: Go to the "Create" tab, name your group (e.g., "Trip to Galle"), and select friends.
4.  **Add Expenses**: Open the group, click `+`, and enter the expense details. You can split equally or by percentage.
5.  **View Settlements**: The app automatically shows "Who owes Who" at the top of the group details page.
6.  **Settle Up**: Once payments are made in real life, you can delete the relevant expenses or the group to clear the history.

## 🛡️ Project Structure

```
Settle/
├── backend/            # Express.js Server
│   ├── models/         # Mongoose Schemas (User, BillSplit)
│   ├── routes/         # API Routes (auth, friends, bills)
│   └── server.js       # Entry point
│
└── frontend/           # Flutter App
    ├── lib/
    │   ├── services/   # API Service calls
    │   ├── main.dart   # App Entry point
    │   └── ...pages    # UI Pages (Dashboard, BillDetails, etc.)
```


