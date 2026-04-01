import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../domain/entities/highlight_selection.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/premium_card.dart';
import '../../widgets/common/premium_header.dart';

class TemplatePreviewScreen extends ConsumerStatefulWidget {
  const TemplatePreviewScreen({super.key});

  @override
  ConsumerState<TemplatePreviewScreen> createState() =>
      _TemplatePreviewScreenState();
}

class _TemplatePreviewScreenState extends ConsumerState<TemplatePreviewScreen> {
  final Map<String, TextEditingController> _controllers = {};
  bool _isGenerating = false;
  Map<String, dynamic>? _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    if (extra != null && _data == null) {
      setState(() => _data = extra);
      _initSampleValues();
    }
  }

  void _initSampleValues() {
    if (_data == null) return;
    final highlights =
        (_data!['highlights'] as List<dynamic>?)?.cast<HighlightSelection>() ??
            [];

    for (final h in highlights) {
      final sampleValue = _getSampleValue(h);
      _controllers[h.fieldName] = TextEditingController(text: sampleValue);
    }
  }

  String _getSampleValue(HighlightSelection h) {
    final name = h.fieldName.toLowerCase();

    if (name.contains('fecha')) return '15 de marzo de 2026';
    if (name.contains('monto')) return '\$50,000.00';
    if (name.contains('nombre')) return 'Juan Pérez García';
    if (name.contains('dirección')) return 'Av. Reforma 123, CDMX';
    if (name.contains('empresa')) return 'Empresa Ejemplo S.A.';
    if (name.contains('documento')) return 'RFC: PEGJ850315ABC';
    if (name.contains('firma')) return '_________________________';

    return h.highlightText;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _generatePreview() async {
    if (_data == null) return;

    setState(() => _isGenerating = true);

    try {
      final highlights = (_data!['highlights'] as List<dynamic>?)
              ?.cast<HighlightSelection>() ??
          [];

      final builder = DocxDocumentBuilder();

      builder.h1(_data!['name'] ?? 'Documento');
      builder.p('');
      builder.p('--- VISTA PREVIA ---', align: DocxAlign.center);
      builder.p('');

      for (final h in highlights) {
        final value = _controllers[h.fieldName]?.text ?? h.highlightText;

        builder.add(DocxParagraph(children: [
          DocxText('${h.fieldName}: ',
              fontWeight: DocxFontWeight.bold, fontSize: 12),
          DocxText(value, fontSize: 12),
        ]));
      }

      final doc = builder.build();
      final dir = await getTemporaryDirectory();
      final fileName = '${_data!['name'] ?? 'documento'}_preview.docx';
      final tempPath = '${dir.path}/$fileName';

      await DocxExporter().exportToFile(doc, tempPath);

      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar vista previa',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['docx'],
      );

      if (savedPath != null) {
        await File(tempPath).copy(savedPath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vista previa guardada exitosamente'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final highlights =
        (_data!['highlights'] as List<dynamic>?)?.cast<HighlightSelection>() ??
            [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PremiumHeader(
            title: 'Vista Previa',
            subtitle: _data!['name'] ?? 'Configurando documento',
            showBackButton: true,
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              itemCount: highlights.length,
              itemBuilder: (ctx, i) {
                final h = highlights[i];
                return PremiumCard(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.edit_note_rounded,
                              size: 18,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            h.fieldName,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Texto original en el documento:',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          h.highlightText,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.onSurface,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _controllers[h.fieldName],
                        hintText: 'Valor de prueba para esta variable',
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: AppButton(
              text: _isGenerating ? 'Generando...' : 'Generar y Exportar .docx',
              icon: _isGenerating ? null : Icons.download_done_rounded,
              isLoading: _isGenerating,
              onPressed: _isGenerating ? null : () => _generatePreview(),
            ),
          ),
        ],
      ),
    );
  }
}
