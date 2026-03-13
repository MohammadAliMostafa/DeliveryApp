import 'package:flutter/material.dart';

import '../../models/business_type_model.dart';
import '../../models/restaurant_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/theme.dart';
import '../../utils/constants.dart';
import 'package:intl/intl.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  String _searchQuery = '';
  String _roleFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              const Text(
                'Users Management',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              FilledButton.icon(
                onPressed: () => _showAddAdminDialog(context),
                icon: const Icon(Icons.person_add),
                label: const Text('Add Admin'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filters
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 600;
              final searchField = TextField(
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
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
                initialValue: _roleFilter,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Roles')),
                  DropdownMenuItem(
                    value: UserRoles.customer,
                    child: Text('Customers'),
                  ),
                  DropdownMenuItem(
                    value: UserRoles.driver,
                    child: Text('Drivers'),
                  ),
                  DropdownMenuItem(
                    value: UserRoles.restaurant,
                    child: Text('Store Owners'),
                  ),
                  DropdownMenuItem(
                    value: UserRoles.admin,
                    child: Text('Admins'),
                  ),
                ],
                onChanged: (val) => setState(() => _roleFilter = val ?? 'all'),
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

          // Users List
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
              child: StreamBuilder<List<UserModel>>(
                stream: firestore.getAllUsers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  var users = snapshot.data ?? [];

                  // Apply filters
                  if (_searchQuery.isNotEmpty) {
                    users = users
                        .where(
                          (u) =>
                              u.name.toLowerCase().contains(_searchQuery) ||
                              u.email.toLowerCase().contains(_searchQuery),
                        )
                        .toList();
                  }

                  if (_roleFilter != 'all') {
                    users = users.where((u) => u.role == _roleFilter).toList();
                  }

                  if (users.isEmpty) {
                    return const Center(
                      child: Text(
                        'No users found.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: users.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getRoleColor(
                            user.role,
                          ).withValues(alpha: 0.2),
                          backgroundImage: user.profileImageUrl != null
                              ? NetworkImage(user.profileImageUrl!)
                              : null,
                          child: user.profileImageUrl == null
                              ? Icon(
                                  Icons.person,
                                  color: _getRoleColor(user.role),
                                )
                              : null,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                user.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (user.isDisabled) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'BANNED',
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: user.role == UserRoles.restaurant
                            ? FutureBuilder<List<RestaurantModel>>(
                                future: firestore.getRestaurants().first,
                                builder: (context, restSnap) {
                                  if (!restSnap.hasData) {
                                    return Text(
                                      '${user.email} • Joined ${DateFormat.yMMMd().format(user.createdAt)}',
                                    );
                                  }

                                  // Find restaurant for this user
                                  final docs = restSnap.data!;
                                  final myStore = docs
                                      .where((d) => d.ownerId == user.uid)
                                      .firstOrNull;

                                  if (myStore == null) {
                                    return Text(
                                      '${user.email} • Joined ${DateFormat.yMMMd().format(user.createdAt)}',
                                    );
                                  }

                                  final String rawType = myStore.businessType;

                                  // Lookup business type display name
                                  return FutureBuilder<List<BusinessTypeModel>>(
                                    future: firestore.getBusinessTypes().first,
                                    builder: (context, typesSnap) {
                                      final types = typesSnap.data ?? [];
                                      final displayType =
                                          types
                                              .where((t) => t.id == rawType)
                                              .firstOrNull
                                              ?.displayName ??
                                          rawType.toUpperCase();

                                      return Text(
                                        '${user.email} • $displayType • Joined ${DateFormat.yMMMd().format(user.createdAt)}',
                                      );
                                    },
                                  );
                                },
                              )
                            : Text(
                                '${user.email} • Joined ${DateFormat.yMMMd().format(user.createdAt)}',
                              ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getRoleColor(
                              user.role,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _getRoleColor(
                                user.role,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: user.role == UserRoles.restaurant
                              ? FutureBuilder<List<RestaurantModel>>(
                                  future: firestore.getRestaurants().first,
                                  builder: (context, restSnap) {
                                    if (!restSnap.hasData)
                                      return Text(
                                        user.role.toUpperCase(),
                                        style: TextStyle(
                                          color: _getRoleColor(user.role),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );

                                    final docs = restSnap.data!;
                                    final myStore = docs
                                        .where((d) => d.ownerId == user.uid)
                                        .firstOrNull;
                                    if (myStore == null)
                                      return Text(
                                        user.role.toUpperCase(),
                                        style: TextStyle(
                                          color: _getRoleColor(user.role),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );

                                    final String rawType = myStore.businessType;

                                    return FutureBuilder<
                                      List<BusinessTypeModel>
                                    >(
                                      future: firestore
                                          .getBusinessTypes()
                                          .first,
                                      builder: (context, typesSnap) {
                                        final types = typesSnap.data ?? [];
                                        final displayType =
                                            types
                                                .where((t) => t.id == rawType)
                                                .firstOrNull
                                                ?.displayName ??
                                            rawType.toUpperCase();

                                        return Text(
                                          displayType.toUpperCase(),
                                          style: TextStyle(
                                            color: _getRoleColor(user.role),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                )
                              : Text(
                                  user.role.toUpperCase(),
                                  style: TextStyle(
                                    color: _getRoleColor(user.role),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                        onTap: () =>
                            _showUserActionsDialog(context, user, firestore),
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

  Color _getRoleColor(String role) {
    switch (role) {
      case UserRoles.admin:
        return Colors.purple;
      case UserRoles.driver:
        return Colors.green;
      case UserRoles.restaurant:
        return Colors.orange;
      case UserRoles.customer:
        return Colors.blue;
      default:
        return AppColors.textSecondary;
    }
  }

  void _showAddAdminDialog(BuildContext context) {
    // This could just be a tip since we can't create auth accounts from admin panel
    // without secondary firebase app instances. Better to promote an existing user.
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Admin'),
        content: const Text(
          'To create a new admin, the user must first sign up normally (or you can use an existing user). '
          'Then, find them in this list and change their role to "Admin".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showUserActionsDialog(
    BuildContext context,
    UserModel user,
    FirestoreService firestore,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        String selectedRole = user.role;
        bool isDisabled = user.isDisabled;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Manage ${user.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Email: ${user.email}'),
                  Text('Phone: ${user.phone.isEmpty ? "N/A" : user.phone}'),
                  const SizedBox(height: 16),

                  // Role Dropdown
                  const Text(
                    'Role',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: UserRoles.customer,
                        child: Text('Customer'),
                      ),
                      DropdownMenuItem(
                        value: UserRoles.driver,
                        child: Text('Driver'),
                      ),
                      DropdownMenuItem(
                        value: UserRoles.restaurant,
                        child: Text('Store Owner'),
                      ),
                      DropdownMenuItem(
                        value: UserRoles.admin,
                        child: Text('Admin'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedRole = val);
                    },
                  ),

                  const SizedBox(height: 16),

                  // Banned Toggle
                  SwitchListTile(
                    title: const Text(
                      'Account Disabled (Banned)',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    activeThumbColor: AppColors.error,
                    value: isDisabled,
                    onChanged: (val) => setDialogState(() => isDisabled = val),
                    contentPadding: EdgeInsets.zero,
                  ),

                  const Divider(),

                  // Delete warning
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Delete Account Data',
                      style: TextStyle(color: AppColors.error),
                    ),
                    subtitle: const Text(
                      'Deletes user document from database. Auth account must be deleted manually in Firebase Console.',
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_forever,
                        color: AppColors.error,
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Delete User Data?'),
                            content: const Text(
                              'This action cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true && context.mounted) {
                          await firestore.deleteUser(user.uid);
                          if (context.mounted) {
                            Navigator.pop(context); // close manage dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('User data deleted'),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (selectedRole != user.role) {
                      await firestore.updateUserRole(user.uid, selectedRole);
                    }
                    if (isDisabled != user.isDisabled) {
                      await firestore.updateUserDisabledStatus(
                        user.uid,
                        isDisabled,
                      );
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
