import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/group_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/group/add_expense_screen.dart';
import 'screens/group/balance_summary_screen.dart';
import 'screens/group/group_detail_screen.dart';
import 'screens/group/group_list_screen.dart';
import 'services/auth_service.dart';
import 'services/group_service.dart';

void main() {
  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(AuthService()),
        ),
        ChangeNotifierProvider<GroupProvider>(
          create: (_) => GroupProvider(GroupService()),
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return MaterialApp(
            title: 'SettleUp',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
              useMaterial3: true,
            ),
            debugShowCheckedModeBanner: false,
            initialRoute: authProvider.isAuthenticated ? GroupListScreen.routeName : LoginScreen.routeName,
            onGenerateRoute: (settings) {
              switch (settings.name) {
                case LoginScreen.routeName:
                  return MaterialPageRoute(builder: (_) => const LoginScreen());
                case GroupListScreen.routeName:
                  return MaterialPageRoute(builder: (_) => const GroupListScreen());
                case GroupDetailScreen.routeName:
                  final args = settings.arguments as GroupDetailArgs;
                  return MaterialPageRoute(builder: (_) => GroupDetailScreen(args: args));
                case AddExpenseScreen.routeName:
                  final args = settings.arguments as AddExpenseArgs;
                  return MaterialPageRoute(builder: (_) => AddExpenseScreen(args: args));
                case BalanceSummaryScreen.routeName:
                  final args = settings.arguments as BalanceSummaryArgs;
                  return MaterialPageRoute(builder: (_) => BalanceSummaryScreen(args: args));
                default:
                  return MaterialPageRoute(builder: (_) => const LoginScreen());
              }
            },
          );
        },
      ),
    );
  }
}
