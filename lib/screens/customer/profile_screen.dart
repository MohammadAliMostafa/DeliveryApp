import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../shared/map_picker_screen.dart';
import '../shared/help_support_screen.dart';
import 'favorites_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            GestureDetector(
              onTap: () =>
                  _editProfile(context, 'Name', user?.name ?? '', (val) {
                    if (user != null) {
                      auth.updateProfile(user.copyWith(name: val));
                    }
                  }),
              child: CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  Helpers.getInitials(user?.name ?? '?'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () =>
                  _editProfile(context, 'Name', user?.name ?? '', (val) {
                    if (user != null) {
                      auth.updateProfile(user.copyWith(name: val));
                    }
                  }),
              child: Text(
                user?.name ?? '',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user?.email ?? '',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),

            // Menu items
            _profileTile(
              icon: Icons.location_on_outlined,
              title: 'Delivery Address',
              subtitle: user?.address ?? 'Set your address',
              onTap: () async {
                final result = await Navigator.push<MapPickerResult>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MapPickerScreen(
                      title: 'Delivery Address',
                      initialLatitude: user?.latitude,
                      initialLongitude: user?.longitude,
                      initialAddress: user?.address,
                    ),
                  ),
                );
                if (result != null && user != null) {
                  auth.updateProfile(
                    user.copyWith(
                      latitude: result.latitude,
                      longitude: result.longitude,
                      address: result.address,
                    ),
                  );
                }
              },
            ),
            _profileTile(
              icon: Icons.phone_outlined,
              title: 'Phone Number',
              subtitle: user?.phone ?? 'Add phone number',
              onTap: () => _editProfile(
                context,
                'Phone Number',
                user?.phone ?? '',
                (val) {
                  if (user != null) {
                    auth.updateProfile(user.copyWith(phone: val));
                  }
                },
              ),
            ),
            _profileTile(
              icon: Icons.favorite_outline,
              title: 'Favorites',
              subtitle: 'Your favorite restaurants & dishes',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                );
              },
            ),
            _profileTile(
              icon: Icons.help_outline,
              title: 'Help & Support',
              subtitle: 'Get help with your orders',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const HelpSupportScreen(userType: 'Customer'),
                  ),
                );
              },
            ),
            _profileTile(
              icon: Icons.info_outline,
              title: 'About',
              subtitle: 'App info and terms',
              onTap: () {},
            ),
            const SizedBox(height: 24),

            // Logout
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => auth.signOut(),
                icon: const Icon(Icons.logout, color: AppColors.error),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(color: AppColors.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editProfile(
    BuildContext context,
    String field,
    String currentValue,
    Function(String) onSave,
  ) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $field'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: field,
            hintText: 'Enter new $field',
          ),
          autofocus: true,
          keyboardType: field == 'Phone Number'
              ? TextInputType.phone
              : TextInputType.text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onSave(controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _profileTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textHint, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: onTap,
    );
  }
}
