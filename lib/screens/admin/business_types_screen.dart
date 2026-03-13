import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../models/business_type_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/theme.dart';

class BusinessTypesScreen extends StatefulWidget {
  const BusinessTypesScreen({super.key});

  @override
  State<BusinessTypesScreen> createState() => _BusinessTypesScreenState();
}

class _BusinessTypesScreenState extends State<BusinessTypesScreen> {
  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 16,
          children: [
            const Text(
              'Business Types Management',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            FilledButton.icon(
              onPressed: () => _showEditTypeDialog(context, null, firestore),
              icon: const Icon(Icons.add),
              label: const Text('Add Type'),
            ),
          ],
        ),
        const SizedBox(height: 24),

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
            child: StreamBuilder<List<BusinessTypeModel>>(
              stream: firestore.getBusinessTypes(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final types = snapshot.data ?? [];

                if (types.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'No business types found.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () => firestore.seedDefaultBusinessTypes(),
                          child: const Text('Seed Defaults'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: types.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final type = types[index];
                    // For icons in Flutter Web, we use IconData, here we just show the string name for simplicity
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: type.color != null
                            ? Color(type.color!).withValues(alpha: 0.2)
                            : AppColors.primary.withValues(alpha: 0.1),
                        child: Icon(
                          type.iconData,
                          color: type.color != null
                              ? Color(type.color!)
                              : AppColors.primary,
                        ),
                      ),
                      title: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            type.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (!type.isActive) ...[
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
                                'INACTIVE',
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
                      subtitle: Text(
                        'ID: ${type.id} • Sort Order: ${type.sortOrder}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: AppColors.primary,
                            ),
                            onPressed: () =>
                                _showEditTypeDialog(context, type, firestore),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: AppColors.error,
                            ),
                            onPressed: () =>
                                _deleteType(context, type, firestore),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showEditTypeDialog(
    BuildContext context,
    BusinessTypeModel? existingType,
    FirestoreService firestore,
  ) {
    final isNew = existingType == null;
    final idCtrl = TextEditingController(text: existingType?.id ?? '');
    final nameCtrl = TextEditingController(
      text: existingType?.displayName ?? '',
    );
    final iconCtrl = TextEditingController(
      text: existingType?.icon ?? 'category',
    );
    int sortOrder = existingType?.sortOrder ?? 0;
    bool isActive = existingType?.isActive ?? true;
    // Default to a vibrant indigo if no color is stored yet
    Color selectedColor = existingType?.color != null
        ? Color(existingType!.color!)
        : const Color(0xFF5C6BC0);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isNew ? 'Add Business Type' : 'Edit Business Type'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: idCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ID (e.g. restaurant)',
                      ),
                      enabled: isNew, // Can't change ID easily after creation
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Display Name (e.g. Restaurants)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: iconCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Icon String (e.g. restaurant)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Sort Order: '),
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () => setDialogState(() => sortOrder--),
                        ),
                        Text(
                          '$sortOrder',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => setDialogState(() => sortOrder++),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      title: const Text('Is Active?'),
                      value: isActive,
                      onChanged: (val) => setDialogState(() => isActive = val),
                    ),
                    const SizedBox(height: 8),
                    // Color Picker row
                    Row(
                      children: [
                        const Text(
                          'Card Colour:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            Color tempColor = selectedColor;
                            showDialog(
                              context: context,
                              builder: (colorCtx) => AlertDialog(
                                title: const Text('Pick a colour'),
                                content: BlockPicker(
                                  pickerColor: selectedColor,
                                  onColorChanged: (c) => tempColor = c,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(colorCtx),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () {
                                      setDialogState(
                                        () => selectedColor = tempColor,
                                      );
                                      Navigator.pop(colorCtx);
                                    },
                                    child: const Text('Select'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: selectedColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.15),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: selectedColor.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '#${selectedColor.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0')}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
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
                    if (idCtrl.text.isEmpty || nameCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('ID and Name are required'),
                        ),
                      );
                      return;
                    }

                    final model = BusinessTypeModel(
                      id: idCtrl.text.trim(),
                      displayName: nameCtrl.text.trim(),
                      icon: iconCtrl.text.trim(),
                      sortOrder: sortOrder,
                      isActive: isActive,
                      color: selectedColor.toARGB32(),
                    );

                    await firestore.saveBusinessType(model);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteType(
    BuildContext context,
    BusinessTypeModel type,
    FirestoreService firestore,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Business Type?'),
        content: Text(
          'Delete "${type.displayName}"? This might break rendering for stores using this type.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await firestore.deleteBusinessType(type.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Business type deleted')));
      }
    }
  }
}
