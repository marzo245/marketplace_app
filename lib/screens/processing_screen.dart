import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/seller_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/processing_steps.dart';

class ProcessingScreen extends StatelessWidget {
  const ProcessingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Consumer<SellerProvider>(
        builder: (context, seller, _) {
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    _HeaderIcon(state: seller.state),
                    const SizedBox(height: 24),
                    Text(
                      _getTitle(seller.state),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getSubtitle(seller.state),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ProcessingSteps(
                        state: seller.state,
                        uploadProgress: seller.uploadProgress,
                        meshyProgress: seller.latestStatus?.progress,
                        productPublished: seller.isProductPublished,
                      ),
                    ),
                    const Spacer(),
                    _ActionArea(seller: seller),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _getTitle(UploadState state) {
    return switch (state) {
      UploadState.uploading => 'Subiendo tu producto',
      UploadState.waitingForModel => 'Producto publicado',
      UploadState.ready => 'Modelo 3D listo',
      UploadState.failed => 'Algo salio mal',
      _ => 'Procesando',
    };
  }

  String _getSubtitle(UploadState state) {
    return switch (state) {
      UploadState.uploading => 'Enviando las fotos al servidor. No cierres la app.',
      UploadState.waitingForModel =>
        'Tu producto ya aparece en el catalogo. Ahora Meshy AI esta generando el modelo 3D en segundo plano.',
      UploadState.ready =>
        'Tu producto ya aparece publicado y ahora tambien tiene vista de realidad aumentada.',
      UploadState.failed => 'Revisa los detalles e intenta de nuevo.',
      _ => '',
    };
  }
}

class _HeaderIcon extends StatelessWidget {
  final UploadState state;
  const _HeaderIcon({required this.state});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (state) {
      UploadState.ready => (AppTheme.success, Icons.check_circle),
      UploadState.failed => (AppTheme.danger, Icons.error),
      _ => (AppTheme.primary, Icons.view_in_ar_outlined),
    };

    final isAnimating = state == UploadState.uploading ||
        state == UploadState.waitingForModel;

    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: isAnimating
            ? Padding(
                padding: const EdgeInsets.all(18),
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              )
            : Icon(icon, color: color, size: 36),
      ),
    );
  }
}

class _ActionArea extends StatelessWidget {
  final SellerProvider seller;
  const _ActionArea({required this.seller});

  @override
  Widget build(BuildContext context) {
    if (seller.state == UploadState.ready) {
      return Column(
        children: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () {
              seller.reset();
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            child: const Text('Volver al inicio'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              seller.reset();
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            child: const Text('Ir al catalogo'),
          ),
        ],
      );
    }

    if (seller.state == UploadState.failed) {
      return Column(
        children: [
          if (seller.error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                seller.error!,
                style: const TextStyle(
                  color: AppTheme.danger,
                  fontSize: 12,
                ),
              ),
            ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => seller.submit(),
            child: const Text('Reintentar'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Editar datos'),
          ),
        ],
      );
    }

    if (seller.state == UploadState.waitingForModel) {
      return TextButton(
        onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        child: const Text('Seguir en segundo plano'),
      );
    }

    return const SizedBox(height: 48);
  }
}
