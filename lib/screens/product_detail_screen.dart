import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/product.dart';
import '../models/product_listing.dart';
import '../services/api_client.dart';
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
  bool _favoriteBusy = false;
  bool _isFavorite = false;
  bool _contactBusy = false;
  bool _purchaseBusy = false;

  @override
  void initState() {
    super.initState();
    _loadFavoriteState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .doc(widget.product.id)
            .snapshots(),
        builder: (context, snapshot) {
          final p = snapshot.hasData && snapshot.data!.exists
              ? ProductListing.fromFirestore(
                  snapshot.data!.id,
                  snapshot.data!.data()!,
                )
              : widget.product;
          final priceFmt = NumberFormat.currency(
            locale: 'es_CO',
            symbol: '\$',
            decimalDigits: 0,
          );

          return CustomScrollView(
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
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? AppTheme.danger : null,
                ),
                onPressed: _favoriteBusy ? null : _toggleFavorite,
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () => _shareProduct(p),
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
                onLaunchAR: () => _launchAR(p),
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
                    _ArProcessingChip(productId: p.id),
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
                  _SellerRow(
                    product: p,
                    onViewProfile: () => _openSellerProfile(p),
                  ),
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
          );
        },
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
                  onPressed: _contactBusy ? null : _contactSeller,
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
                  onPressed: _purchaseBusy ? null : _registerPurchaseIntent,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Solicitar compra'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchAR(ProductListing product) async {
    if (_launchingAr) return;
    setState(() => _launchingAr = true);

    final messenger = ScaffoldMessenger.of(context);
    final result = await widget.arService.launchAR(
      productTitle: product.title,
      glbUrl: product.model3d?.glbUrl,
      usdzUrl: product.model3d?.usdzUrl,
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

  Future<void> _loadFavoriteState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final favoriteDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(widget.product.id)
          .get();
      if (!mounted) return;
      setState(() => _isFavorite = favoriteDoc.exists);
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inicia sesión para guardar favoritos'),
        ),
      );
      return;
    }

    setState(() => _favoriteBusy = true);
    final favoriteRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(widget.product.id);

    try {
      if (_isFavorite) {
        await favoriteRef.delete();
      } else {
        await favoriteRef.set({
          'productId': widget.product.id,
          'title': widget.product.title,
          'price': widget.product.price,
          'photo': widget.product.firstPhoto,
          'sellerId': widget.product.sellerId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      setState(() => _isFavorite = !_isFavorite);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFavorite ? 'Agregado a favoritos' : 'Eliminado de favoritos',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar favoritos: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _favoriteBusy = false);
      }
    }
  }

  Future<void> _shareProduct(ProductListing p) async {
    final priceFmt = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );
    final links = <String>[
      if (p.firstPhoto.isNotEmpty) p.firstPhoto,
      if (p.model3d?.glbUrl != null) p.model3d!.glbUrl!,
      if (p.model3d?.usdzUrl != null) p.model3d!.usdzUrl!,
    ];

    final message = [
      'Mira este producto en Marketplace 3D:',
      p.title,
      priceFmt.format(p.price),
      if (p.description.isNotEmpty) p.description,
      'ID: ${p.id}',
      if (links.isNotEmpty) '',
      ...links,
    ].join('\n');

    await Share.share(
      message,
      subject: p.title,
    );
  }

  Future<void> _contactSeller() async {
    await _submitBuyerAction(
      type: 'contact_request',
      collection: 'product_inquiries',
      successMessage: 'Tu interés fue enviado al vendedor',
      busySetter: (value) => _contactBusy = value,
    );
  }

  Future<void> _registerPurchaseIntent() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inicia sesión para continuar'),
        ),
      );
      return;
    }

    if (widget.product.sellerId == user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No puedes solicitar la compra de tu propio producto'),
        ),
      );
      return;
    }

    try {
      final existing = await FirebaseFirestore.instance
          .collection('purchase_intents')
          .where('productId', isEqualTo: widget.product.id)
          .where('buyerId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ya habías enviado una solicitud de compra para este producto'),
          ),
        );
        return;
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo validar la solicitud: $error'),
        ),
      );
      return;
    }

    await _submitBuyerAction(
      type: 'purchase_intent',
      collection: 'purchase_intents',
      successMessage: 'Tu solicitud de compra fue registrada',
      busySetter: (value) => _purchaseBusy = value,
    );
  }

  Future<void> _submitBuyerAction({
    required String type,
    required String collection,
    required String successMessage,
    required void Function(bool) busySetter,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inicia sesión para continuar'),
        ),
      );
      return;
    }

    setState(() => busySetter(true));
    try {
      await FirebaseFirestore.instance.collection(collection).add({
        'type': type,
        'status': 'new',
        'productId': widget.product.id,
        'productTitle': widget.product.title,
        'productPrice': widget.product.price,
        'sellerId': widget.product.sellerId,
        'sellerName': widget.product.sellerName,
        'buyerId': user.uid,
        'buyerName': user.displayName,
        'buyerEmail': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo completar la acción: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => busySetter(false));
      }
    }
  }

  void _openSellerProfile(ProductListing product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellerProfileScreen(
          sellerId: product.sellerId,
          sellerName: product.sellerName ?? 'Vendedor',
          sellerRating: product.sellerRating,
          arService: widget.arService,
        ),
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

class _ArProcessingChip extends StatefulWidget {
  final String productId;

  const _ArProcessingChip({required this.productId});

  @override
  State<_ArProcessingChip> createState() => _ArProcessingChipState();
}

class _ArProcessingChipState extends State<_ArProcessingChip> {
  static const _accent = Color(0xFFBA7517);
  static const _bg = Color(0xFFFFF4E5);

  Timer? _timer;
  int? _progress;
  Model3DStatus? _status;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final api = context.read<ApiClient>();
      final status = await api.getProductStatus(widget.productId);
      if (!mounted) return;
      setState(() {
        _progress = status.progress;
        _status = status.status;
      });
      if (status.status == Model3DStatus.ready ||
          status.status == Model3DStatus.failed) {
        _timer?.cancel();
      }
    } catch (_) {
      // soft-fail; keep polling
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final isFailed = _status == Model3DStatus.failed;
    final fraction = (progress ?? 0).clamp(0, 100) / 100.0;
    final label = isFailed
        ? 'No se pudo generar la vista 3D'
        : (progress == null
            ? 'Generando vista 3D...'
            : 'Generando vista 3D · $progress%');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: _accent,
                  value: isFailed
                      ? 0
                      : (progress == null ? null : fraction),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: _accent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (!isFailed && progress != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 4,
                backgroundColor: _accent.withAlpha(40),
                valueColor: const AlwaysStoppedAnimation<Color>(_accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SellerRow extends StatelessWidget {
  final ProductListing product;
  final VoidCallback onViewProfile;
  const _SellerRow({required this.product, required this.onViewProfile});

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
            onPressed: onViewProfile,
            child: const Text('Ver perfil'),
          ),
        ],
      ),
    );
  }
}

class SellerProfileScreen extends StatelessWidget {
  final String sellerId;
  final String sellerName;
  final double? sellerRating;
  final ArService arService;

  const SellerProfileScreen({
    super.key,
    required this.sellerId,
    required this.sellerName,
    required this.sellerRating,
    required this.arService,
  });

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('products')
        .where('status', isEqualTo: 'published')
        .where('sellerId', isEqualTo: sellerId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del vendedor'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('No se pudo cargar el perfil del vendedor'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }

          final products = snapshot.data!.docs
              .map((doc) => ProductListing.fromFirestore(doc.id, doc.data()))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppTheme.surface,
                        child: Text(
                          sellerName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sellerName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${products.length} productos publicados',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                            if (sellerRating != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    size: 14,
                                    color: Color(0xFFEF9F27),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    sellerRating!.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (products.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'Este vendedor aún no tiene productos publicados',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = products[index];
                        return _SellerProductCard(
                          product: product,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(
                                product: product,
                                arService: arService,
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: products.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SellerProductCard extends StatelessWidget {
  final ProductListing product;
  final VoidCallback onTap;

  const _SellerProductCard({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final priceFmt = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(10),
                    ),
                    child: Container(
                      color: const Color(0xFFF5F5F7),
                      width: double.infinity,
                      child: product.firstPhoto.isNotEmpty
                          ? Image.network(
                              product.firstPhoto,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image_outlined,
                                color: Colors.black26,
                              ),
                            )
                          : const Icon(
                              Icons.image_outlined,
                              color: Colors.black26,
                              size: 32,
                            ),
                    ),
                  ),
                  if (product.hasAr)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.view_in_ar,
                              size: 10,
                              color: Colors.white,
                            ),
                            SizedBox(width: 3),
                            Text(
                              '3D · AR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, height: 1.2),
                      ),
                    ),
                    Text(
                      priceFmt.format(product.price),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
