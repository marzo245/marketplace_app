import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../theme/app_theme.dart';

class Product3DViewer extends StatelessWidget {
  final String glbUrl;
  final String? usdzUrl;
  final String productTitle;
  final VoidCallback onLaunchAR;
  final double aspectRatio;

  const Product3DViewer({
    super.key,
    required this.glbUrl,
    required this.productTitle,
    required this.onLaunchAR,
    this.usdzUrl,
    this.aspectRatio = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ModelViewer(
              src: glbUrl,
              iosSrc: usdzUrl,
              alt: productTitle,
              cameraControls: true,
              autoRotate: true,
              autoRotateDelay: 3000,
              rotationPerSecond: '30deg',
              ar: false,
              backgroundColor: const Color(0xFFF5F5F7),
              exposure: 1.1,
              shadowIntensity: 1,
              shadowSoftness: 0.6,
              disableZoom: false,
              loading: Loading.eager,
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.threed_rotation,
                      color: Colors.white,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '3D',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: _ArButton(onPressed: onLaunchAR),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _ArButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.view_in_ar,
                size: 16,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Ver en mi casa',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PhotoViewer extends StatelessWidget {
  final String imageUrl;
  final double aspectRatio;

  const PhotoViewer({
    super.key,
    required this.imageUrl,
    this.aspectRatio = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          color: const Color(0xFFF5F5F7),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primary,
                ),
              );
            },
            errorBuilder: (context, error, stack) => const Center(
              child: Icon(Icons.broken_image_outlined, color: Colors.black26),
            ),
          ),
        ),
      ),
    );
  }
}

class MediaCarousel extends StatefulWidget {
  final List<String> photos;
  final String? glbUrl;
  final String? usdzUrl;
  final String productTitle;
  final VoidCallback onLaunchAR;

  const MediaCarousel({
    super.key,
    required this.photos,
    required this.productTitle,
    required this.onLaunchAR,
    this.glbUrl,
    this.usdzUrl,
  });

  @override
  State<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<MediaCarousel> {
  late final PageController _ctrl;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final has3D = widget.glbUrl != null;
    final items = <Widget>[
      if (has3D)
        Product3DViewer(
          glbUrl: widget.glbUrl!,
          usdzUrl: widget.usdzUrl,
          productTitle: widget.productTitle,
          onLaunchAR: widget.onLaunchAR,
        ),
      ...widget.photos.map((url) => PhotoViewer(imageUrl: url)),
    ];

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: PageView(
            controller: _ctrl,
            onPageChanged: (i) => setState(() => _page = i),
            children: items,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(items.length, (i) {
            final selected = i == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: selected ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : Colors.black26,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}
