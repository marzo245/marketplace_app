import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
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
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? AppTheme.danger : null,
                ),
                onPressed: _favoriteBusy ? null : _toggleFavorite,
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: _shareProduct,
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

  Future<void> _shareProduct() async {
    final p = widget.product;
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

    await SharePlus.instance.share(
      ShareParams(
        text: message,
        subject: p.title,
      ),
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
    await _submitBuyerAction(
      type: 'purchase_intent',
      collection: 'purchase_intents',
      successMessage: 'Tu intención de compra fue registrada',
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
