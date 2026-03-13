import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/theme.dart';
import '../../utils/constants.dart';
import 'admin_driver_map.dart';
import 'admin_driver_detail_screen.dart';

class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key});

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Drivers Management',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const SizedBox(
            height: 300,
            width: double.infinity,
            child: AdminDriverMap(),
          ),
          const SizedBox(height: 24),

          // Filters
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 600;
              final searchField = TextField(
                decoration: InputDecoration(
                  hintText: 'Search by driver name...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (value) =>
                    setState(() => _searchQuery = value.toLowerCase()),
              );

              final dropdownField = DropdownButtonFormField<String>(
                initialValue: _statusFilter,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                  DropdownMenuItem(
                    value: DriverStatus.idle,
                    child: Text('Offline (Idle)'),
                  ),
                  DropdownMenuItem(
                    value: DriverStatus.online,
                    child: Text('Online (Waiting)'),
                  ),
                  DropdownMenuItem(
                    value: DriverStatus.pickingUp,
                    child: Text('Picking Up'),
                  ),
                  DropdownMenuItem(
                    value: DriverStatus.delivering,
                    child: Text('Delivering'),
                  ),
                ],
                onChanged: (val) =>
                    setState(() => _statusFilter = val ?? 'all'),
              );

              if (isDesktop) {
                return Row(
                  children: [
                    Expanded(flex: 2, child: searchField),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: dropdownField),
                  ],
                );
              } else {
                return Column(
                  children: [
                    searchField,
                    const SizedBox(height: 16),
                    dropdownField,
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 24),

          // Drivers List
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              // We don't have a specific getAllDrivers stream, but we have getAllUsers
              // which we can filter. Since this is admin panel, processing client side is okay for a realistically sized list.
              child: StreamBuilder<List<UserModel>>(
                stream: firestore
                    .getAllUsers(), // Filtering for role='driver' later
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  var drivers = (snapshot.data ?? [])
                      .where((u) => u.role == UserRoles.driver)
                      .toList();

                  if (_searchQuery.isNotEmpty) {
                    drivers = drivers
                        .where(
                          (d) => d.name.toLowerCase().contains(_searchQuery),
                        )
                        .toList();
                  }

                  if (_statusFilter != 'all') {
                    // if status filter is set, driverStatus field should match
                    // if driverStatus is null, default is 'idle'
                    drivers = drivers
                        .where(
                          (d) =>
                              (d.driverStatus ?? DriverStatus.idle) ==
                              _statusFilter,
                        )
                        .toList();
                  }

                  if (drivers.isEmpty) {
                    return const Center(
                      child: Text(
                        'No drivers found.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: drivers.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final driver = drivers[index];
                      final currentStatus =
                          driver.driverStatus ?? DriverStatus.idle;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.withValues(alpha: 0.2),
                          backgroundImage: driver.profileImageUrl != null
                              ? NetworkImage(driver.profileImageUrl!)
                              : null,
                          child: driver.profileImageUrl == null
                              ? const Icon(
                                  Icons.delivery_dining,
                                  color: Colors.green,
                                )
                              : null,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                driver.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (currentStatus != DriverStatus.idle) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.circle,
                                color: AppColors.success,
                                size: 10,
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          driver.phone.isEmpty ? driver.email : driver.phone,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildStatusBadge(currentStatus),
                            IconButton(
                              icon: const Icon(Icons.power_settings_new),
                              tooltip: 'Force Offline',
                              onPressed: () => _forceDriverOffline(
                                context,
                                driver,
                                firestore,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminDriverDetailScreen(
                                driver: driver,
                                firestore: firestore,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;

    switch (status) {
      case DriverStatus.online:
        color = Colors.green;
        label = 'ONLINE';
        break;
      case DriverStatus.pickingUp:
        color = Colors.orange;
        label = 'PICKING UP';
        break;
      case DriverStatus.delivering:
        color = Colors.blue;
        label = 'DELIVERING';
        break;
      case DriverStatus.idle:
      default:
        color = Colors.grey;
        label = 'OFFLINE';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _forceDriverOffline(
    BuildContext context,
    UserModel driver,
    FirestoreService firestore,
  ) async {
    final status = driver.driverStatus ?? DriverStatus.idle;

    if (status == DriverStatus.idle) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver is already offline.')),
      );
      return;
    }

    if (status == DriverStatus.pickingUp || status == DriverStatus.delivering) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Force Offline?'),
          content: const Text(
            'Warning: This driver is currently fulfilling an order. Forcing them offline may break their delivery flow. It is recommended to reassign their order first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Force Offline'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    await firestore.updateDriverStatus(driver.uid, DriverStatus.idle);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Forced ${driver.name} offline.')));
    }
  }
}
