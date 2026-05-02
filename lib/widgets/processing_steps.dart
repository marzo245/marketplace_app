import 'package:flutter/material.dart';
import '../providers/seller_provider.dart';
import '../theme/app_theme.dart';

class ProcessingSteps extends StatelessWidget {
  final UploadState state;
  final double uploadProgress;
  final int? meshyProgress;

  const ProcessingSteps({
    super.key,
    required this.state,
    required this.uploadProgress,
    this.meshyProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Step(
          number: 1,
          title: 'Subiendo fotos',
          subtitle: state == UploadState.uploading
              ? '${(uploadProgress * 100).toInt()}% enviado'
              : 'Fotos enviadas al servidor',
          status: _getStep1Status(),
        ),
        _Connector(active: state.index >= UploadState.waitingForModel.index),
        _Step(
          number: 2,
          title: 'Generando modelo 3D',
          subtitle: meshyProgress != null && meshyProgress! > 0
              ? 'Meshy AI procesando... ${meshyProgress}%'
              : 'Esto toma entre 1 y 3 minutos',
          status: _getStep2Status(),
        ),
        _Connector(active: state == UploadState.ready),
        _Step(
          number: 3,
          title: 'Producto publicado',
          subtitle: 'Visible en el catálogo con vista AR',
          status: _getStep3Status(),
        ),
      ],
    );
  }

  _StepStatus _getStep1Status() {
    if (state == UploadState.idle) return _StepStatus.pending;
    if (state == UploadState.uploading) return _StepStatus.active;
    if (state == UploadState.failed && uploadProgress < 1) return _StepStatus.failed;
    return _StepStatus.done;
  }

  _StepStatus _getStep2Status() {
    if (state.index < UploadState.waitingForModel.index) return _StepStatus.pending;
    if (state == UploadState.waitingForModel) return _StepStatus.active;
    if (state == UploadState.failed) return _StepStatus.failed;
    return _StepStatus.done;
  }

  _StepStatus _getStep3Status() {
    if (state == UploadState.ready) return _StepStatus.done;
    if (state == UploadState.failed) return _StepStatus.pending;
    return _StepStatus.pending;
  }
}

enum _StepStatus { pending, active, done, failed }

class _Step extends StatelessWidget {
  final int number;
  final String title;
  final String subtitle;
  final _StepStatus status;

  const _Step({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIcon(status: status, number: number),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: status == _StepStatus.pending ? Colors.black38 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: status == _StepStatus.failed
                        ? AppTheme.danger
                        : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIcon extends StatelessWidget {
  final _StepStatus status;
  final int number;

  const _StepIcon({required this.status, required this.number});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case _StepStatus.done:
        return Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: AppTheme.success,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 16),
        );
      case _StepStatus.active:
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Padding(
            padding: EdgeInsets.all(5),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppTheme.primary),
            ),
          ),
        );
      case _StepStatus.failed:
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppTheme.danger.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, color: AppTheme.danger, size: 16),
        );
      case _StepStatus.pending:
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F7),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.black38,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
    }
  }
}

class _Connector extends StatelessWidget {
  final bool active;
  const _Connector({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 13),
      width: 1,
      height: 12,
      color: active ? AppTheme.success : const Color(0xFFE5E5E8),
    );
  }
}
