import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/seller_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/photo_grid.dart';
import 'processing_screen.dart';

class SellProductScreen extends StatefulWidget {
  const SellProductScreen({super.key});

  @override
  State<SellProductScreen> createState() => _SellProductScreenState();
}

class _SellProductScreenState extends State<SellProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Publicar producto',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<SellerProvider>(
        builder: (context, seller, _) {
          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PhotoGrid(
                            photos: seller.draft.photos,
                            onAddCamera: seller.addPhotoFromCamera,
                            onAddGallery: seller.addPhotosFromGallery,
                            onRemove: seller.removePhoto,
                          ),
                          if (seller.error != null &&
                              seller.state == UploadState.idle)
                            _ErrorBanner(message: seller.error!),
                          const SizedBox(height: 24),
                          _FieldLabel('Título'),
                          TextFormField(
                            controller: _titleCtrl,
                            maxLength: 120,
                            onChanged: seller.updateTitle,
                            decoration: const InputDecoration(
                              hintText: 'Ej. Sofá modular 3 puestos gris',
                              counterText: '',
                            ),
                          ),
                          const SizedBox(height: 16),
                          _FieldLabel('Precio'),
                          TextFormField(
                            controller: _priceCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              _ThousandsFormatter(),
                            ],
                            onChanged: (v) {
                              final cleaned = v.replaceAll('.', '');
                              seller.updatePrice(double.tryParse(cleaned));
                            },
                            decoration: const InputDecoration(
                              hintText: '0',
                              prefixText: '\$ ',
                              prefixStyle: TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _FieldLabel('Categoría'),
                          _CategorySelector(
                            selected: seller.draft.category,
                            onChanged: seller.updateCategory,
                          ),
                          const SizedBox(height: 16),
                          _FieldLabel('Descripción (opcional)'),
                          TextFormField(
                            controller: _descCtrl,
                            maxLines: 4,
                            maxLength: 2000,
                            onChanged: seller.updateDescription,
                            decoration: const InputDecoration(
                              hintText: 'Estado, dimensiones, material, detalles...',
                            ),
                          ),
                          const SizedBox(height: 24),
                          _InfoCard(),
                        ],
                      ),
                    ),
                  ),
                ),
                _SubmitBar(
                  draft: seller.draft,
                  onSubmit: () => _submit(context, seller),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _submit(BuildContext context, SellerProvider seller) async {
    final scaffold = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final ok = await seller.submit();
    if (!mounted) return;

    if (ok) {
      navigator.push(
        MaterialPageRoute(builder: (_) => const ProcessingScreen()),
      );
    } else if (seller.error != null) {
      scaffold.showSnackBar(
        SnackBar(content: Text(seller.error!)),
      );
    }
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _CategorySelector extends StatelessWidget {
  final ProductCategory selected;
  final ValueChanged<ProductCategory> onChanged;

  const _CategorySelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ProductCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = ProductCategory.values[i];
          final isSelected = cat == selected;
          return GestureDetector(
            onTap: () => onChanged(cat),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                cat.label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_outlined, size: 18, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Al publicar, generaremos automáticamente un modelo 3D con Meshy AI '
              'para que tus compradores vean el producto en su casa con realidad aumentada.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withValues(alpha: 0.75),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.danger, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  final ProductDraft draft;
  final VoidCallback onSubmit;

  const _SubmitBar({required this.draft, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final valid = draft.isValid;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: FilledButton(
        onPressed: valid ? onSubmit : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primary,
          disabledBackgroundColor: const Color(0xFFE5E5E8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, size: 18),
            const SizedBox(width: 8),
            const Text('Publicar y generar 3D'),
          ],
        ),
      ),
    );
  }
}

class _ThousandsFormatter extends TextInputFormatter {
  final _formatter = NumberFormat.decimalPattern('es_CO');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final digits = newValue.text.replaceAll('.', '');
    final number = int.tryParse(digits);
    if (number == null) return oldValue;
    final formatted = _formatter.format(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
