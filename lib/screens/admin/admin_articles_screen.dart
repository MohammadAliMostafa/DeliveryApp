import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../models/article_model.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../utils/theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class AdminArticlesScreen extends StatefulWidget {
  const AdminArticlesScreen({super.key});

  @override
  State<AdminArticlesScreen> createState() => _AdminArticlesScreenState();
}

class _AdminArticlesScreenState extends State<AdminArticlesScreen> {
  final FirestoreService _firestore = FirestoreService();
  final StorageService _storage = StorageService();
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Articles Management',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              FilledButton.icon(
                onPressed: () => _showArticleDialog(context, null),
                icon: const Icon(Icons.add),
                label: const Text('Add Article'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ArticleModel>>(
            stream: _firestore.getArticles(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final articles = snapshot.data ?? [];
              if (articles.isEmpty) {
                return const Center(
                  child: Text(
                    'No articles found.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                itemCount: articles.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final article = articles[index];
                  return _buildArticleTile(context, article);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildArticleTile(BuildContext context, ArticleModel article) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 60,
            height: 60,
            child: article.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: article.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey.shade200),
                    errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                  )
                : const Icon(Icons.image, color: Colors.grey),
          ),
        ),
        title: Text(
          article.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          article.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.primary),
              onPressed: () => _showArticleDialog(context, article),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: AppColors.error),
              onPressed: () => _deleteArticle(context, article),
            ),
          ],
        ),
      ),
    );
  }

  void _showArticleDialog(BuildContext context, ArticleModel? existing) {
    final isNew = existing == null;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final imgUrlCtrl = TextEditingController(text: existing?.imageUrl ?? '');
    Uint8List? pickedImageBytes;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isNew ? 'New Article' : 'Edit Article'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final XFile? image = await _picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1920,
                        maxHeight: 1080,
                        imageQuality: 85,
                      );
                      if (image != null) {
                        final bytes = await image.readAsBytes();
                        setDialogState(() {
                          pickedImageBytes = bytes;
                          imgUrlCtrl.text = ''; // Clear URL if image picked
                        });
                      }
                    },
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: pickedImageBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(pickedImageBytes!, fit: BoxFit.cover),
                            )
                          : existing?.imageUrl.isNotEmpty == true && imgUrlCtrl.text.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: existing!.imageUrl,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text('Tap to pick image', style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title'),
                    enabled: !isUploading,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                    enabled: !isUploading,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: imgUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Or Paste Image URL',
                      hintText: 'https://...',
                    ),
                    enabled: !isUploading && pickedImageBytes == null,
                  ),
                  if (isUploading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isUploading ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isUploading
                    ? null
                    : () async {
                        if (titleCtrl.text.isEmpty || descCtrl.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Title and Description are required')),
                          );
                          return;
                        }

                        if (pickedImageBytes == null && imgUrlCtrl.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please upload an image or provide a URL')),
                          );
                          return;
                        }

                        setDialogState(() => isUploading = true);

                        try {
                          String imageUrl = imgUrlCtrl.text.trim();

                          if (pickedImageBytes != null) {
                            final fileName = const Uuid().v4();
                            imageUrl = await _storage.uploadImageBytes(
                              'articles/$fileName.jpg',
                              pickedImageBytes!,
                            );
                          }

                          final article = ArticleModel(
                            id: existing?.id ?? '',
                            title: titleCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            imageUrl: imageUrl,
                            createdAt: existing?.createdAt ?? DateTime.now(),
                          );

                          await _firestore.saveArticle(article);
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          setDialogState(() => isUploading = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteArticle(BuildContext context, ArticleModel article) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Article?'),
        content: Text('Delete "${article.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await _firestore.deleteArticle(article.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Article deleted')),
        );
      }
    }
  }
}
