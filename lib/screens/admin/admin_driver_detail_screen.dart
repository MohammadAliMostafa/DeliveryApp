import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/order_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/theme.dart';

class AdminDriverDetailScreen extends StatelessWidget {
  final UserModel driver;
  final FirestoreService firestore;

  const AdminDriverDetailScreen({
    super.key,
    required this.driver,
    required this.firestore,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${driver.name}\'s Profile')),
      body: StreamBuilder<List<OrderModel>>(
        stream: firestore.getDriverDeliveredOrders(driver.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: SelectableText(
                'Error loading driver stats: ${snapshot.error}',
                style: const TextStyle(color: AppColors.error),
              ),
            );
          }

          final orders = snapshot.data ?? [];
          final double totalEarnings = orders.fold(
            0.0,
            (sum, order) => sum + order.deliveryFee,
          );
          final int totalDeliveries = orders.length;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDriverHeader(),
                const SizedBox(height: 24),
                _buildMetricsRow(totalDeliveries, totalEarnings),
                const SizedBox(height: 24),
                const Text(
                  'Completed Deliveries',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: orders.isEmpty
                      ? const Center(
                          child: Text(
                            'No completed deliveries found.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : _buildDeliveriesList(orders),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDriverHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: Colors.green.withValues(alpha: 0.2),
          backgroundImage: driver.profileImageUrl != null
              ? NetworkImage(driver.profileImageUrl!)
              : null,
          child: driver.profileImageUrl == null
              ? const Icon(Icons.delivery_dining, size: 32, color: Colors.green)
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                driver.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${driver.email} • ${driver.phone.isEmpty ? "No Phone" : driver.phone}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Joined ${DateFormat.yMMMd().format(driver.createdAt)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsRow(int totalDeliveries, double totalEarnings) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            title: 'Total Deliveries',
            value: totalDeliveries.toString(),
            icon: Icons.check_circle_outline,
            color: AppColors.info,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricCard(
            title: 'Total Earnings',
            value: '\$${totalEarnings.toStringAsFixed(2)}',
            icon: Icons.attach_money,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveriesList(List<OrderModel> orders) {
    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.success.withValues(alpha: 0.1),
              child: const Icon(Icons.done_all, color: AppColors.success),
            ),
            title: Text(
              'Order #${order.id.substring(0, 8)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${DateFormat.yMMMd().format(order.createdAt)} at ${DateFormat.jm().format(order.createdAt)}\nStore: ${order.restaurantName}',
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Earnings',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '\$${order.deliveryFee.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
