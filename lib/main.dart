import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'models/product_listing.dart';
import 'providers/auth_provider.dart';
import 'providers/seller_provider.dart';
import 'screens/catalog_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/sell_product_screen.dart';
import 'services/api_client.dart';
import 'services/ar_service.dart';
import 'services/auth_service.dart';
import 'services/photo_service.dart';
import 'services/push_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final apiClient = ApiClient();
  final photoService = PhotoService();
  final arService = ArService();

  try {
    await dotenv.load(fileName: '.env').timeout(const Duration(seconds: 2));
  } catch (e) {
    debugPrint('[bootstrap] dotenv skipped: $e');
  }

  AuthService? authService;
  PushService? pushService;
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 6));
    authService = AuthService();
    pushService = PushService();
    firebaseReady = true;
    debugPrint('[bootstrap] firebase ok');
  } catch (e) {
    debugPrint('[bootstrap] firebase failed, falling back to demo: $e');
  }

  runApp(MarketplaceApp(
    apiClient: apiClient,
    photoService: photoService,
    arService: arService,
    authService: authService,
    pushService: pushService,
    demoMode: !firebaseReady,
  ));
}

class MarketplaceApp extends StatelessWidget {
  final ApiClient apiClient;
  final PhotoService photoService;
  final ArService arService;
  final AuthService? authService;
  final PushService? pushService;
  final bool demoMode;

  const MarketplaceApp({
    super.key,
    required this.apiClient,
    required this.photoService,
    required this.arService,
    required this.authService,
    required this.pushService,
    required this.demoMode,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        Provider<PhotoService>.value(value: photoService),
        Provider<ArService>.value(value: arService),
        if (!demoMode && authService != null && pushService != null) ...[
          Provider<AuthService>.value(value: authService!),
          Provider<PushService>.value(value: pushService!),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(
              authService: authService!,
              apiClient: apiClient,
              pushService: pushService!,
            ),
          ),
        ],
        ChangeNotifierProvider(
          create: (_) => SellerProvider(
            api: apiClient,
            photos: photoService,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Marketplace 3D',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: RootShell(demoMode: demoMode),
      ),
    );
  }
}

class RootShell extends StatefulWidget {
  final bool demoMode;

  const RootShell({super.key, required this.demoMode});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    final arService = context.read<ArService>();

    final pages = [
      CatalogScreen(arService: arService, demoMode: widget.demoMode),
      _SellEntry(demoMode: widget.demoMode),
      _ProfilePlaceholder(demoMode: widget.demoMode, arService: arService),
    ];

    return Scaffold(
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Tienda',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Vender',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class _SellEntry extends StatelessWidget {
  final bool demoMode;

  const _SellEntry({required this.demoMode});

  @override
  Widget build(BuildContext context) {
    if (demoMode) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vender')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.visibility_off_outlined, size: 56, color: AppTheme.primary),
                SizedBox(height: 16),
                Text(
                  'Modo demo activo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 6),
                Text(
                  'Falta configurar Firebase para publicar de verdad.\nPor ahora puedes explorar el catálogo y el detalle 3D.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        return Scaffold(
          appBar: AppBar(title: const Text('Vender')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_a_photo_outlined,
                    size: 56,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Publica tu producto',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Genera un modelo 3D automáticamente desde tus fotos',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  if (user != null) ...[
                    Text(
                      'Sesión iniciada como ${user.displayName ?? user.email ?? user.uid}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                      ),
                      onPressed: auth.busy
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SellProductScreen(),
                                ),
                              ),
                      child: const Text('Empezar publicación'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: auth.busy ? null : () => auth.signOut(),
                      child: const Text('Cerrar sesión'),
                    ),
                  ] else ...[
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                      ),
                      onPressed: auth.busy ? null : () => auth.signInWithGoogle(),
                      icon: auth.busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: const Text('Iniciar sesión con Google'),
                    ),
                    if (auth.error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        auth.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.danger, fontSize: 12),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfilePlaceholder extends StatelessWidget {
  final bool demoMode;
  final ArService arService;

  const _ProfilePlaceholder({
    required this.demoMode,
    required this.arService,
  });

  @override
  Widget build(BuildContext context) {
    if (demoMode) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_outline, size: 56, color: AppTheme.primary),
                SizedBox(height: 16),
                Text(
                  'Perfil en modo demo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 6),
                Text(
                  'Cuando configures Firebase Auth aquí verás tu sesión, favoritos y solicitudes de compra.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Perfil')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppTheme.surface,
                      child: const Text(
                        'P',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Perfil',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Inicia sesión para ver favoritos y solicitudes de compra',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                      onPressed: auth.busy ? null : () => auth.signInWithGoogle(),
                      icon: auth.busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: const Text('Iniciar sesión con Google'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return _ProfileTabsScaffold(
          user: user,
          busy: auth.busy,
          onSignOut: auth.signOut,
          onOpenProduct: (productId) => _openProduct(context, productId),
        );
      },
    );
  }

  Future<void> _openProduct(BuildContext context, String productId) async {
    if (productId.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();
      if (!snap.exists) {
        messenger.showSnackBar(
          const SnackBar(content: Text('El producto ya no está disponible')),
        );
        return;
      }

      final product = ProductListing.fromFirestore(snap.id, snap.data()!);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(
            product: product,
            arService: arService,
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo abrir el producto: $error')),
      );
    }
  }
}

class _ProfileTabsScaffold extends StatefulWidget {
  final dynamic user;
  final bool busy;
  final Future<void> Function() onSignOut;
  final Future<void> Function(String productId) onOpenProduct;

  const _ProfileTabsScaffold({
    required this.user,
    required this.busy,
    required this.onSignOut,
    required this.onOpenProduct,
  });

  @override
  State<_ProfileTabsScaffold> createState() => _ProfileTabsScaffoldState();
}

class _ProfileTabsScaffoldState extends State<_ProfileTabsScaffold> {
  var _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    final tabs = [
      _MyProductsTab(
        sellerId: user.uid,
        onOpenProduct: widget.onOpenProduct,
      ),
      _SavedItemsTab(
        title: 'Aún no tienes favoritos',
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('favorites')
            .snapshots(),
        onOpenProduct: widget.onOpenProduct,
      ),
      _PurchaseIntentsTab(
        emptyText: 'Aún no has enviado solicitudes de compra',
        stream: FirebaseFirestore.instance
            .collection('purchase_intents')
            .where('buyerId', isEqualTo: user.uid)
            .snapshots(),
        isSellerView: false,
        onOpenProduct: widget.onOpenProduct,
      ),
      _PurchaseIntentsTab(
        emptyText: 'Aún no has recibido solicitudes',
        stream: FirebaseFirestore.instance
            .collection('purchase_intents')
            .where('sellerId', isEqualTo: user.uid)
            .snapshots(),
        isSellerView: true,
        onOpenProduct: widget.onOpenProduct,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.surface,
                  child: Text(
                    (user.displayName ?? user.email ?? 'P')
                        .substring(0, 1)
                        .toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName ?? 'Perfil',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                  ),
                  onPressed: widget.busy ? null : widget.onSignOut,
                  child: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _ProfileTabChip(
                  label: 'Míos',
                  selected: _tabIndex == 0,
                  onTap: () => setState(() => _tabIndex = 0),
                ),
                const SizedBox(width: 8),
                _ProfileTabChip(
                  label: 'Favoritos',
                  selected: _tabIndex == 1,
                  onTap: () => setState(() => _tabIndex = 1),
                ),
                const SizedBox(width: 8),
                _ProfileTabChip(
                  label: 'Enviadas',
                  selected: _tabIndex == 2,
                  onTap: () => setState(() => _tabIndex = 2),
                ),
                const SizedBox(width: 8),
                _ProfileTabChip(
                  label: 'Recibidas',
                  selected: _tabIndex == 3,
                  onTap: () => setState(() => _tabIndex = 3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: tabs[_tabIndex]),
        ],
      ),
    );
  }
}

class _SavedItemsTab extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String title;
  final Future<void> Function(String productId) onOpenProduct;

  const _SavedItemsTab({
    required this.stream,
    required this.title,
    required this.onOpenProduct,
  });

  @override
  Widget build(BuildContext context) {
    final priceFmt = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('No se pudieron cargar los favoritos'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(child: Text(title));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = docs[index].data();
            return ListTile(
              tileColor: const Color(0xFFFAFAFB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: (data['photo'] as String?)?.isNotEmpty == true
                      ? Image.network(
                          data['photo'] as String,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined),
                        )
                      : const Icon(Icons.image_outlined),
                ),
              ),
              title: Text(data['title'] as String? ?? 'Producto'),
              subtitle: Text(
                priceFmt.format((data['price'] as num?)?.toDouble() ?? 0),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onOpenProduct(data['productId'] as String? ?? ''),
            );
          },
        );
      },
    );
  }
}

class _PurchaseIntentsTab extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String emptyText;
  final bool isSellerView;
  final Future<void> Function(String productId) onOpenProduct;

  const _PurchaseIntentsTab({
    required this.stream,
    required this.emptyText,
    required this.isSellerView,
    required this.onOpenProduct,
  });

  @override
  Widget build(BuildContext context) {
    final priceFmt = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('No se pudieron cargar las solicitudes'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(child: Text(emptyText));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final counterpart = isSellerView
                ? (data['buyerName'] as String? ??
                    data['buyerEmail'] as String? ??
                    'Comprador')
                : (data['sellerName'] as String? ?? 'Vendedor');
            final counterpartLabel = isSellerView ? 'Comprador' : 'Vendedor';

            return ListTile(
              tileColor: const Color(0xFFFAFAFB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              title: Text(data['productTitle'] as String? ?? 'Producto'),
              subtitle: Text(
                '${priceFmt.format((data['productPrice'] as num?)?.toDouble() ?? 0)}\n$counterpartLabel: $counterpart',
              ),
              isThreeLine: true,
              trailing: _StatusChip(status: data['status'] as String? ?? 'new'),
              onTap: () => onOpenProduct(data['productId'] as String? ?? ''),
            );
          },
        );
      },
    );
  }
}

class _MyProductsTab extends StatelessWidget {
  final String sellerId;
  final Future<void> Function(String productId) onOpenProduct;

  const _MyProductsTab({
    required this.sellerId,
    required this.onOpenProduct,
  });

  @override
  Widget build(BuildContext context) {
    final priceFmt = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    final query = FirebaseFirestore.instance
        .collection('products')
        .where('sellerId', isEqualTo: sellerId);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('No se pudieron cargar tus productos'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final at = a.data()['createdAt'];
            final bt = b.data()['createdAt'];
            DateTime parse(dynamic v) {
              if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
              if (v is DateTime) return v;
              try {
                return (v as dynamic).toDate();
              } catch (_) {
                return DateTime.fromMillisecondsSinceEpoch(0);
              }
            }
            return parse(bt).compareTo(parse(at));
          });

        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Aún no tienes productos publicados',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final status = data['status'] as String? ?? 'published';
            final photos = (data['photos'] as List?)?.cast<String>() ?? const [];
            final firstPhoto = photos.isNotEmpty ? photos.first : '';

            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFB),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: firstPhoto.isNotEmpty
                          ? Image.network(
                              firstPhoto,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.image_outlined),
                            )
                          : const Icon(Icons.image_outlined),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['title'] as String? ?? 'Producto',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          priceFmt.format(
                            (data['price'] as num?)?.toDouble() ?? 0,
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _StatusChip(status: status),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'open':
                          await onOpenProduct(doc.id);
                          break;
                        case 'edit':
                          await _showEditDialog(context, doc.reference, data);
                          break;
                        case 'unpublish':
                          await _confirmUnpublish(context, doc.reference);
                          break;
                        case 'republish':
                          await doc.reference.update({'status': 'published'});
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'open',
                        child: ListTile(
                          leading: Icon(Icons.open_in_new),
                          title: Text('Ver'),
                          dense: true,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar'),
                          dense: true,
                        ),
                      ),
                      if (status == 'published')
                        const PopupMenuItem(
                          value: 'unpublish',
                          child: ListTile(
                            leading: Icon(Icons.visibility_off_outlined),
                            title: Text('Despublicar'),
                            dense: true,
                          ),
                        )
                      else
                        const PopupMenuItem(
                          value: 'republish',
                          child: ListTile(
                            leading: Icon(Icons.publish_outlined),
                            title: Text('Republicar'),
                            dense: true,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    final titleCtrl = TextEditingController(
      text: data['title'] as String? ?? '',
    );
    final descCtrl = TextEditingController(
      text: data['description'] as String? ?? '',
    );
    final priceCtrl = TextEditingController(
      text: ((data['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(0),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar producto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Precio'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              minimumSize: const Size(0, 40),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (saved != true) return;

    final newPrice = double.tryParse(priceCtrl.text.trim().replaceAll(',', '.'));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.update({
        'title': titleCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        if (newPrice != null) 'price': newPrice,
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Producto actualizado')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $e')),
      );
    }
  }

  Future<void> _confirmUnpublish(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Despublicar producto'),
        content: const Text(
          'El producto dejará de aparecer en el catálogo. Podrás republicarlo después.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.danger,
              minimumSize: const Size(0, 40),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Despublicar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.update({'status': 'unpublished'});
      messenger.showSnackBar(
        const SnackBar(content: Text('Producto despublicado')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo despublicar: $e')),
      );
    }
  }
}

class _ProfileTabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ProfileTabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : const Color(0xFFFAFAFB),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppTheme.primary : const Color(0xFFE0E0E0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = switch (normalized) {
      'accepted' => AppTheme.success,
      'rejected' => AppTheme.danger,
      'completed' => AppTheme.success,
      _ => AppTheme.primary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        normalized,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
