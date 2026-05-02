import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/seller_provider.dart';
import 'screens/catalog_screen.dart';
import 'screens/sell_product_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/ar_service.dart';
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
  bool firebaseReady = false;
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
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final arService = context.read<ArService>();

    final pages = [
      CatalogScreen(arService: arService, demoMode: widget.demoMode),
      _SellEntry(demoMode: widget.demoMode),
      _ProfilePlaceholder(demoMode: widget.demoMode),
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
                  const Icon(Icons.add_a_photo_outlined,
                      size: 56, color: AppTheme.primary),
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

  const _ProfilePlaceholder({required this.demoMode});

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
                  'Cuando configures Firebase Auth aquí verás tu sesión, tokens FCM y opciones de cuenta.',
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
                    child: Text(
                      (user?.displayName ?? user?.email ?? 'P').substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.displayName ?? 'Perfil',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user?.email ?? 'Inicia sesión para guardar tus tokens FCM y publicar productos',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  if (user == null)
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
                    )
                  else
                    FilledButton.tonal(
                      onPressed: auth.busy ? null : () => auth.signOut(),
                      child: const Text('Cerrar sesión'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
