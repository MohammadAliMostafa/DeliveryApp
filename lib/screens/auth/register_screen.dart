import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/business_type_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import '../shared/help_support_screen.dart';


class RegisterScreen extends StatefulWidget {
  final VoidCallback onLoginTap;

  const RegisterScreen({super.key, required this.onLoginTap});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _licensePlateController = TextEditingController();
  final _storeNameController = TextEditingController();
  final _storeAddressController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  String _selectedRole = UserRoles.customer;
  String? _selectedBusinessType;
  bool _obscurePassword = true;

  final _roleOptions = [
    {'value': UserRoles.customer, 'label': 'Customer', 'icon': Icons.person},
    {
      'value': UserRoles.driver,
      'label': 'Driver',
      'icon': Icons.delivery_dining,
    },
    {
      'value': UserRoles.restaurant,
      'label': 'Store Owner',
      'icon': Icons.store,
    },
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _vehicleTypeController.dispose();
    _licensePlateController.dispose();
    _storeNameController.dispose();
    _storeAddressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final authProvider = context.read<AuthProvider>();
    authProvider.clearError();

    Map<String, dynamic> formData = {};
    if (_selectedRole == UserRoles.driver) {
      formData = {
        'vehicleType': _vehicleTypeController.text.trim(),
        'licensePlate': _licensePlateController.text.trim(),
      };
    } else if (_selectedRole == UserRoles.restaurant) {
      if (_selectedBusinessType == null) {
        context.read<AuthProvider>().clearError();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a business type')),
        );
        return;
      }
      formData = {
        'storeName': _storeNameController.text.trim(),
        'storeAddress': _storeAddressController.text.trim(),
        'businessType': _selectedBusinessType,
      };
    }

    await authProvider.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text.trim(),
      role: _selectedRole,
      phone: _phoneController.text.trim(),
      formData: formData,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryDark, AppColors.primary],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Header
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/images/logo_white.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Join Porter today',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Form card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Role selector
                          const Text(
                            'I am a...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: _roleOptions.map((opt) {
                              final isSelected = opt['value'] == _selectedRole;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(
                                    () =>
                                        _selectedRole = opt['value'] as String,
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.background,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.divider,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          opt['icon'] as IconData,
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.textSecondary,
                                          size: 24,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          opt['label'] as String,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? Colors.white
                                                : AppColors.textSecondary,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),

                          // Name
                          TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) => v == null || v.isEmpty
                                ? 'Please enter your name'
                                : null,
                          ),
                          const SizedBox(height: 14),

                          // Email
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!v.contains('@')) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Phone
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: _selectedRole == UserRoles.customer
                                  ? 'Phone (optional)'
                                  : 'Phone (required)',
                              prefixIcon: const Icon(Icons.phone_outlined),
                            ),
                            validator: (v) {
                              if (_selectedRole != UserRoles.customer &&
                                  (v == null || v.trim().isEmpty)) {
                                return 'Phone number is required for applications';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Dynamic fields based on role
                          if (_selectedRole == UserRoles.driver) ...[
                            TextFormField(
                              controller: _vehicleTypeController,
                              decoration: const InputDecoration(
                                labelText: 'Vehicle Type (e.g., Car, Bike)',
                                prefixIcon: Icon(Icons.directions_car_outlined),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Vehicle type is required'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _licensePlateController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'License Plate',
                                prefixIcon: Icon(Icons.pin_outlined),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'License plate is required'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (_selectedRole == UserRoles.restaurant) ...[
                            TextFormField(
                              controller: _storeNameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Store Name',
                                prefixIcon: Icon(Icons.store_outlined),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Store name is required'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _storeAddressController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Store Address',
                                prefixIcon: Icon(Icons.location_on_outlined),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Store address is required'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            StreamBuilder<List<BusinessTypeModel>>(
                              stream: _firestoreService.getBusinessTypes(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                final types = snapshot.data ?? [];

                                return DropdownButtonFormField<String>(
                                  value: _selectedBusinessType,
                                  decoration: const InputDecoration(
                                    labelText: 'Business Type',
                                    prefixIcon: Icon(Icons.category_outlined),
                                  ),
                                  items: types.map((t) {
                                    return DropdownMenuItem(
                                      value: t.id,
                                      child: Text(t.displayName),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedBusinessType = val;
                                    });
                                  },
                                  validator: (v) => v == null
                                      ? 'Business type is required'
                                      : null,
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Password
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Error
                          Consumer<AuthProvider>(
                            builder: (context, auth, _) {
                              if (auth.error != null) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    auth.error!,
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),

                          // Register button
                          Consumer<AuthProvider>(
                            builder: (context, auth, _) {
                              return SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: auth.isLoading ? null : _submit,
                                  child: auth.isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Create Account'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Login link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onLoginTap,
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Get Help link
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              HelpSupportScreen(userType: _selectedRole),
                        ),
                      );
                    },
                    icon: const Icon(Icons.help_outline, color: Colors.white),
                    label: const Text(
                      'Get help',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
