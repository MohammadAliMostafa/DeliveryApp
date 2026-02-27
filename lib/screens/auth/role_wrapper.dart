import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../customer/customer_shell.dart';
import '../driver/driver_shell.dart';
import '../restaurant/restaurant_shell.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// Decides which interface to show based on user role
class RoleWrapper extends StatelessWidget {
  const RoleWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // Loading
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Not logged in — show auth flow
        if (!auth.isLoggedIn) {
          return const AuthFlow();
        }

        // Route by role
        switch (auth.userRole) {
          case UserRoles.customer:
            return const CustomerShell();
          case UserRoles.driver:
            return const DriverShell();
          case UserRoles.restaurant:
            return const RestaurantShell();
          default:
            return const CustomerShell();
        }
      },
    );
  }
}

/// Switches between Login and Register screens
class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  bool _showLogin = true;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _showLogin
          ? LoginScreen(
              key: const ValueKey('login'),
              onRegisterTap: () => setState(() => _showLogin = false),
            )
          : RegisterScreen(
              key: const ValueKey('register'),
              onLoginTap: () => setState(() => _showLogin = true),
            ),
    );
  }
}
