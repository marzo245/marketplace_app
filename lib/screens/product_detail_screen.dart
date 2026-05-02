import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product_listing.dart';
import '../services/ar_service.dart';
import '../theme/app_theme.dart';
import '../widgets/product_3d_viewer.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductListing product;
  final ArService arService;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.arService,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _launchingAr = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final priceFmt = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0,
            title: const Text(
              'Detalle',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.favorite_border),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () {},
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: MediaCarousel(
                photos: p.photos,
                glbUrl: p.model3d?.glbUrl,
                usdzUrl: p.model3d?.usdzUrl,
                productTitle: p.title,
                onLaunchAR: _launchAR,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.hasAr)
                    _ArAvailableChip()
                  else if (p.model3d?.status == 'processing' ||
                           p.model3d?.status == 'queued')
                    _ArProcessingChip(),
                  const SizedBox(height: 12),
                  Text(
                    p.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    priceFmt.format(p.price),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SellerRow(product: p),
                  const SizedBox(height: 20),
                  const Text(
                    'Descripción',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p.description.isEmpty ? 'Sin descripción' : p.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: const Text('Contactar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Comprar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchAR() async {
    if (_launchingAr) return;
    setState(() => _launchingAr = true);

    final messenger = ScaffoldMessenger.of(context);
    final result = await widget.arService.launchAR(
      productTitle: widget.product.title,
      glbUrl: widget.product.model3d?.glbUrl,
      usdzUrl: widget.product.model3d?.usdzUrl,
    );

    if (!mounted) return;
    setState(() => _launchingAr = false);

    if (result.success) return;

    final canInstallArCore = result.reason == ArCapability.launchFailed;
    messenger.showSnackBar(
      SnackBar(
        content: Text(result.userMessage),
        action: canInstallArCore
            ? SnackBarAction(
                label: 'Instalar',
                onPressed: () => widget.arService.openArCoreInstaller(),
              )
            : null,
      ),
    );
  }
}

class _ArAvailableChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.view_in_ar, size: 14, color: AppTheme.primary),
          SizedBox(width: 6),
          Text(
            'Disponible en realidad aumentada',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArProcessingChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Color(0xFFBA7517),
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Generando vista 3D...',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFFBA7517),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SellerRow extends StatelessWidget {
  final ProductListing product;
  const _SellerRow({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.surface,
            child: Text(
              (product.sellerName ?? 'V').substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.sellerName ?? 'Vendedor',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.star, size: 12, color: Color(0xFFEF9F27)),
                    const SizedBox(width: 2),
                    Text(
                      product.sellerRating?.toStringAsFixed(1) ?? '—',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text('Ver perfil'),
          ),
        ],
      ),
    );
  }
}

