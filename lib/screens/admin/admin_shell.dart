import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';

// Admin screens
import 'dashboard_screen.dart';
import 'users_screen.dart';
import 'stores_screen.dart';
import 'orders_screen.dart';
import 'drivers_screen.dart';
import 'requests_screen.dart';
import 'admin_articles_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const UsersScreen(),
    const StoresScreen(),
    const OrdersScreen(),
    const DriversScreen(),
    const AdminRequestsScreen(),
    const AdminArticlesScreen(),
  ];

  final List<String> _titles = [
    'Dashboard',
    'Users Management',
    'Stores Management',
    'Orders Management',
    'Drivers Management',
    'Applications Management',
    'Articles Management',
  ];

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                'Admin: ${user?.name ?? ''}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(user?.name ?? 'Admin'),
              accountEmail: Text(user?.email ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: const Icon(
                  Icons.admin_panel_settings,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),
              decoration: const BoxDecoration(color: AppColors.primary),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(0, Icons.dashboard, 'Dashboard'),
                  _buildDrawerItem(1, Icons.people, 'Users'),
                  _buildDrawerItem(2, Icons.store, 'Stores'),
                  _buildDrawerItem(3, Icons.receipt_long, 'Orders'),
                  _buildDrawerItem(4, Icons.delivery_dining, 'Drivers'),
                  _buildDrawerItem(
                    5,
                    Icons.assignment_ind,
                    'Requests',
                    trailing: _buildPendingBadge(),
                  ),
                  _buildDrawerItem(6, Icons.article, 'Articles'),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Navigator.pop(context); // Close drawer
                context.read<AuthProvider>().signOut();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      body: IndexedStack(index: _selectedIndex, children: _screens),
    );
  }

  Widget _buildDrawerItem(
    int index,
    IconData icon,
    String title, {
    Widget? trailing,
  }) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: trailing,
      selected: isSelected,
      selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        Navigator.pop(context); // Close drawer
      },
    );
  }

  Widget _buildPendingBadge() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('applications')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final count = snapshot.data!.docs.length;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count > 99 ? '99+' : count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}
