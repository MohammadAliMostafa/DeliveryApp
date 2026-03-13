import 'package:flutter/material.dart';

import '../../models/order_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/theme.dart';
import '../../utils/constants.dart';
import 'package:intl/intl.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
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
            'Orders Management',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Filters
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 600;
              final searchField = TextField(
                decoration: InputDecoration(
                  hintText: 'Search by order ID or customer name...',
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
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('All Statuses'),
                  ),
                  ...OrderStatus.allStatuses.map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(OrderStatus.displayName(s)),
                    ),
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

          // Orders List
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
              child: StreamBuilder<List<OrderModel>>(
                stream: firestore.getAllOrders(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  var orders = snapshot.data ?? [];

                  if (_searchQuery.isNotEmpty) {
                    orders = orders
                        .where(
                          (o) =>
                              o.id.toLowerCase().contains(_searchQuery) ||
                              o.customerName.toLowerCase().contains(
                                _searchQuery,
                              ) ||
                              o.restaurantName.toLowerCase().contains(
                                _searchQuery,
                              ),
                        )
                        .toList();
                  }

                  if (_statusFilter != 'all') {
                    orders = orders
                        .where((o) => o.status == _statusFilter)
                        .toList();
                  }

                  if (orders.isEmpty) {
                    return const Center(
                      child: Text(
                        'No orders found.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: orders.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return ListTile(
                        title: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            Text(
                              'Order #${order.id.substring(0, 8)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '\$${order.total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '${order.customerName}  →  ${order.restaurantName}',
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat.yMMMd().add_jm().format(
                                order.createdAt,
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              order.status,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _getStatusColor(
                                order.status,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            OrderStatus.displayName(order.status).toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(order.status),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        onTap: () =>
                            _showOrderDetailsDialog(context, order, firestore),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case OrderStatus.placed:
        return Colors.blue;
      case OrderStatus.accepted:
        return Colors.indigo;
      case OrderStatus.preparing:
        return Colors.orange;
      case OrderStatus.ready:
        return Colors.teal;
      case OrderStatus.pickedUp:
        return Colors.purple;
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  void _showOrderDetailsDialog(
    BuildContext context,
    OrderModel order,
    FirestoreService firestore,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        String selectedStatus = order.status;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Order #${order.id.substring(0, 8)}'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _buildDetailRow(
                      'Customer',
                      '${order.customerName} (${order.customerPhone ?? "No phone"})',
                    ),
                    _buildDetailRow(
                      'Store',
                      '${order.restaurantName} (${order.restaurantPhone ?? "No phone"})',
                    ),
                    _buildDetailRow('Driver', order.driverName ?? "Unassigned"),
                    _buildDetailRow('Address', order.deliveryAddress),
                    const Divider(),
                    const Text(
                      'Items:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...order.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${item.quantity}x ${item.name}'),
                            Text('\$${item.totalPrice.toStringAsFixed(2)}'),
                          ],
                        ),
                      ),
                    ),
                    const Divider(),
                    _buildDetailRow(
                      'Subtotal',
                      '\$${order.subtotal.toStringAsFixed(2)}',
                    ),
                    _buildDetailRow(
                      'Delivery Fee',
                      '\$${order.deliveryFee.toStringAsFixed(2)}',
                    ),
                    _buildDetailRow(
                      'Total',
                      '\$${order.total.toStringAsFixed(2)}',
                      isBold: true,
                    ),

                    const SizedBox(height: 24),
                    const Text(
                      'Admin Override Status:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: OrderStatus.allStatuses
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(OrderStatus.displayName(s)),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null)
                          setDialogState(() => selectedStatus = val);
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Warning: Forcing status might bypass app logic (e.g. driver payments).',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (selectedStatus != order.status) {
                      await firestore.updateOrderStatus(
                        order.id,
                        selectedStatus,
                      );
                    }
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Save Status'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
