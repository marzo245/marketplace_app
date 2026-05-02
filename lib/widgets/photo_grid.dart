import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PhotoGrid extends StatelessWidget {
  final List<File> photos;
  final VoidCallback onAddCamera;
  final VoidCallback onAddGallery;
  final ValueChanged<int> onRemove;
  final int maxPhotos;

  const PhotoGrid({
    super.key,
    required this.photos,
    required this.onAddCamera,
    required this.onAddGallery,
    required this.onRemove,
    this.maxPhotos = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Fotos del producto',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${photos.length}/$maxPhotos',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Sube 2 a 4 fotos desde ángulos distintos para un mejor modelo 3D',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: maxPhotos,
          itemBuilder: (context, index) {
            if (index < photos.length) {
              return _PhotoTile(
                file: photos[index],
                onRemove: () => onRemove(index),
                index: index,
              );
            }
            final isNextSlot = index == photos.length;
            return _AddPhotoTile(
              enabled: isNextSlot,
              onCamera: onAddCamera,
              onGallery: onAddGallery,
            );
          },
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;
  final int index;

  const _PhotoTile({
    required this.file,
    required this.onRemove,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(file, fit: BoxFit.cover),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
        Positioned(
          bottom: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final bool enabled;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _AddPhotoTile({
    required this.enabled,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? () => _showPicker(context) : null,
      child: Container(
        decoration: BoxDecoration(
          color: enabled ? AppTheme.surface : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? AppTheme.primary.withValues(alpha: 0.3) : Colors.transparent,
            style: enabled ? BorderStyle.solid : BorderStyle.none,
          ),
        ),
        child: Icon(
          Icons.add_a_photo_outlined,
          color: enabled ? AppTheme.primary : Colors.black26,
          size: 20,
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primary),
                title: const Text('Tomar foto'),
                onTap: () {
                  Navigator.pop(ctx);
                  onCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primary),
                title: const Text('Elegir de galería'),
                onTap: () {
                  Navigator.pop(ctx);
                  onGallery();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
