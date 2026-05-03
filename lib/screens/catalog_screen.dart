import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/product_listing.dart';
import '../providers/auth_provider.dart';
import '../services/ar_service.dart';
import '../theme/app_theme.dart';
import 'product_detail_screen.dart';

class CatalogScreen extends StatefulWidget {
  final ArService arService;
  final bool demoMode;

  const CatalogScreen({super.key, required this.arService, this.demoMode = false});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  static const int _pageSize = 20;

  final _search = TextEditingController();
  final _scrollController = ScrollController();

  String _filter = 'all';
  String _searchTerm = '';

  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  String _locationLabel = 'Cargando ubicación...';

  final List<ProductListing> _products = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;

  static final List<ProductListing> _demoProducts = [
    ProductListing(
      id: 'demo_1',
      title: 'Sofá modular gris 3 puestos',
      description: 'Tela suave, estructura en madera y vista 3D lista para AR.',
      price: 1850000,
      category: 'muebles',
      sellerId: 'demo_seller',
      sellerName: 'Casa Nube',
      sellerRating: 4.8,
      photos: const [
        'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?auto=format&fit=crop&w=1200&q=80',
      ],
      model3d: Model3D(
        status: 'ready',
        glbUrl: 'https://modelviewer.dev/shared-assets/models/Astronaut.glb',
        usdzUrl: 'https://modelviewer.dev/shared-assets/models/Astronaut.usdz',
      ),
      createdAt: DateTime.now(),
    ),
    ProductListing(
      id: 'demo_2',
      title: 'Lámpara decorativa minimalista',
      description: 'Ideal para sala o escritorio con estilo moderno.',
      price: 220000,
      category: 'iluminacion',
      sellerId: 'demo_seller',
      sellerName: 'Luz Clara',
      sellerRating: 4.6,
      photos: const [
        'https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=1200&q=80',
      ],
      model3d: Model3D(
        status: 'ready',
        glbUrl: 'https://modelviewer.dev/shared-assets/models/RobotExpressive.glb',
        usdzUrl: 'https://modelviewer.dev/shared-assets/models/RobotExpressive.usdz',
      ),
      createdAt: DateTime.now(),
    ),
    ProductListing(
      id: 'demo_3',
      title: 'Organizador de cocina premium',
      description: 'Producto sin modelo 3D todavía para mostrar el estado mixto.',
      price: 89000,
      category: 'otros',
      sellerId: 'demo_seller',
      sellerName: 'Orden Hogar',
      sellerRating: 4.4,
      photos: const [
        'https://images.unsplash.com/photo-1495521821757-a1efb6729352?auto=format&fit=crop&w=1200&q=80',
      ],
      model3d: Model3D(status: 'processing'),
      createdAt: DateTime.now(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.demoMode) {
        setState(() {
          _products
            ..clear()
            ..addAll(_demoProducts);
          _loadingInitial = false;
          _hasMore = false;
        });
      } else {
        _loadFirstPage();
      }
    });
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => _locationLabel = 'Ubicación desactivada');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationLabel = 'Ubicación no disponible');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;
      if (placemarks.isEmpty) {
        setState(() => _locationLabel = 'Ubicación no disponible');
        return;
      }

      final p = placemarks.first;
      final city = (p.locality?.isNotEmpty ?? false)
          ? p.locality!
          : (p.subAdministrativeArea ?? p.administrativeArea ?? '');
      final country = p.isoCountryCode ?? p.country ?? '';
      final label = [city, country].where((s) => s.isNotEmpty).join(', ');
      setState(() => _locationLabel = label.isEmpty ? 'Ubicación no disponible' : label);
    } catch (_) {
      if (mounted) setState(() => _locationLabel = 'Ubicación no disponible');
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || !_hasMore || _loadingMore || _loadingInitial) {
      return;
    }

    final threshold = _scrollController.position.maxScrollExtent - 600;
    if (_scrollController.position.pixels >= threshold) {
      _loadMore();
    }
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('products')
        .where('status', isEqualTo: 'published');

    if (_filter == 'ar') {
      q = q.where('model3d.status', isEqualTo: 'ready');
    } else if (_filter != 'all') {
      q = q.where('category', isEqualTo: _filter);
    }

    return q.orderBy('createdAt', descending: true);
  }

  Future<void> _loadFirstPage() async {
    if (widget.demoMode) return;

    setState(() {
      _loadingInitial = true;
      _loadingMore = false;
      _hasMore = true;
      _error = null;
      _products.clear();
      _lastDoc = null;
    });

    try {
      final snap = await _buildQuery().limit(_pageSize).get();
      final items = snap.docs
          .map((doc) => ProductListing.fromFirestore(doc.id, doc.data()))
          .toList();

      setState(() {
        _products.addAll(items);
        _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
        _hasMore = snap.docs.length == _pageSize;
        _loadingInitial = false;
      });
    } catch (e) {
      setState(() {
        _error = 'No se pudo cargar el catálogo';
        _loadingInitial = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (widget.demoMode) return;

    if (!_hasMore || _loadingMore || _lastDoc == null) return;

    setState(() => _loadingMore = true);

    try {
      final snap = await _buildQuery()
          .startAfterDocument(_lastDoc!)
          .limit(_pageSize)
          .get();

      final items = snap.docs
          .map((doc) => ProductListing.fromFirestore(doc.id, doc.data()))
          .toList();

      setState(() {
        _products.addAll(items);
        if (snap.docs.isNotEmpty) {
          _lastDoc = snap.docs.last;
        }
        _hasMore = snap.docs.length == _pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      setState(() {
        _loadingMore = false;
        _error = 'No se pudieron cargar más productos';
      });
    }
  }

  void _changeFilter(String value) {
    if (_filter == value) return;
    setState(() => _filter = value);
    _loadFirstPage();
  }

  List<ProductListing> get _visibleProducts {
    final term = _searchTerm.trim().toLowerCase();
    if (term.isEmpty) return _products;

    return _products.where((product) {
      return product.title.toLowerCase().contains(term) ||
          product.description.toLowerCase().contains(term);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilters(),
            const SizedBox(height: 4),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final user = context.watch<AuthProvider>().user;
    final isGuest = user == null;
    final displayName = isGuest
        ? 'Invitado'
        : (user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : (user.email ?? 'Usuario'));
    final initial = displayName.isNotEmpty
        ? displayName.characters.first.toUpperCase()
        : '?';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HOLA,',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: Colors.black54),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            _locationLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.surface,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            onChanged: (value) => setState(() => _searchTerm = value),
            decoration: InputDecoration(
              hintText: 'Buscar productos...',
              prefixIcon: const Icon(Icons.search, size: 18, color: Colors.black54),
              isDense: true,
              hintStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final filters = [
      ('all', 'Todos', null),
      ('ar', 'Con vista 3D', Icons.view_in_ar),
      ('muebles', 'Muebles', null),
      ('decoracion', 'Decoración', null),
      ('electro', 'Electro', null),
      ('iluminacion', 'Iluminación', null),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final (value, label, icon) = filters[i];
          final selected = _filter == value;
          return GestureDetector(
            onTap: () => _changeFilter(value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppTheme.surface : const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 13,
                      color: selected ? AppTheme.primary : Colors.black54,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? AppTheme.primary : Colors.black87,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingInitial) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (_error != null && _products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                onPressed: _loadFirstPage,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final visible = _visibleProducts;
    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _searchTerm.isNotEmpty
                ? 'No encontramos productos con esa búsqueda'
                : 'Aún no hay productos en esta categoría',
            style: const TextStyle(color: Colors.black54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: visible.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (_loadingMore && i >= visible.length) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        final product = visible[i];
        return _ProductCard(
          product: product,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(
                product: product,
                arService: widget.arService,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductListing product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

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
