import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../data/datasources/remote/supabase_datasource.dart';
import '../../../services/docx_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/premium_card.dart';
import '../../widgets/common/premium_header.dart';

class TemplateReviewScreen extends ConsumerStatefulWidget {
  const TemplateReviewScreen({super.key});

  @override
  ConsumerState<TemplateReviewScreen> createState() =>
      _TemplateReviewScreenState();
}

class _TemplateReviewScreenState extends ConsumerState<TemplateReviewScreen> {
  bool _isGenerating = false;
  Map<String, dynamic>? _data;
  String _documentText = '';
  bool _isLoadingDoc = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    if (extra != null && _data == null) {
      setState(() => _data = extra);
      _loadDocumentText();
    }
  }

  Future<void> _loadDocumentText() async {
    if (_data == null) return;
    final template = _data!['template'] as Map<String, dynamic>;
    final fileUrl = template['file_url'] as String?;
    if (fileUrl == null || fileUrl.isEmpty) return;

    setState(() => _isLoadingDoc = true);
    try {
      final supabase = Supabase.instance.client;
      final datasource = SupabaseDatasource(supabase);
      final docxService = DocxService();

      final docxBytes = await datasource.downloadDocxFile(fileUrl);
      final text = await docxService.extractPlainText(docxBytes);

      if (mounted) {
        setState(() {
          _documentText = text;
          _isLoadingDoc = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingDoc = false);
    }
  }

  Future<void> _generateDocument() async {
    if (_data == null) return;

    setState(() => _isGenerating = true);

    try {
      final supabase = Supabase.instance.client;
      final datasource = SupabaseDatasource(supabase);
      final docxService = DocxService();

      final template = _data!['template'] as Map<String, dynamic>;
      final automations =
          (_data!['automations'] as List<dynamic>).cast<Map<String, dynamic>>();
      final filledValues = (_data!['filledValues'] as Map<String, dynamic>)
          .cast<String, String>();

      final replacements = <String, String>{};
      for (final auto in automations) {
        final highlightText = auto['highlight_text'] as String;
        final autoId = auto['id'] as String;
        var value = filledValues[autoId] ?? '';

        if (value.isNotEmpty) {
          final isUppercase = auto['uppercase'] == true;
          if (isUppercase) {
            value = value.toUpperCase();
          }
          replacements[highlightText] = value;
        }
      }

      final fileUrl = template['file_url'] as String?;
      final templateName = template['name'] ?? 'documento';

      if (fileUrl == null || fileUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Esta plantilla no tiene un archivo .docx original.'),
            ),
          );
        }
        return;
      }

      final docxBytes = await datasource.downloadDocxFile(fileUrl);
      final modifiedBytes =
          await docxService.replaceTextInDocument(docxBytes, replacements);

      final defaultName = '${templateName}_llenado.docx';
      final dir = await getTemporaryDirectory();
      final tempPath = '${dir.path}/$defaultName';
      await docxService.exportToFile(modifiedBytes, tempPath);

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar documento como...',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: ['docx'],
      );

      if (savePath != null) {
        await File(tempPath).copy(savePath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Documento guardado en:\n$savePath'),
              duration: const Duration(seconds: 4),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Widget _buildDocumentWithReplacements(
    List<Map<String, dynamic>> automations,
    Map<String, String> filledValues,
  ) {
    if (_documentText.isEmpty) {
      return const Center(
        child: Text('No se pudo cargar el texto del documento'),
      );
    }

    final replacementDisplay = <String, String>{};
    final replacementColors = <String, bool>{}; 
    for (final auto in automations) {
      final highlightText = auto['highlight_text'] as String;
      final autoId = auto['id'] as String;
      final value = filledValues[autoId] ?? '';
      final isUppercase = auto['uppercase'] == true;

      if (value.isNotEmpty) {
        replacementDisplay[highlightText] =
            isUppercase ? value.toUpperCase() : value;
        replacementColors[highlightText] = true;
      } else {
        replacementDisplay[highlightText] = highlightText;
        replacementColors[highlightText] = false;
      }
    }

    final segments = <_TextSegment>[];
    final regex = RegExp(r'\{\{[^}]+\}\}');
    int lastEnd = 0;

    for (final match in regex.allMatches(_documentText)) {
      if (match.start > lastEnd) {
        segments.add(
            _TextSegment.plain(_documentText.substring(lastEnd, match.start)));
      }
      final placeholder = match.group(0)!;
      final displayValue = replacementDisplay[placeholder] ?? placeholder;
      final hasValue = replacementColors[placeholder] ?? false;
      segments.add(_TextSegment.replaced(placeholder, displayValue, hasValue));
      lastEnd = match.end;
    }
    if (lastEnd < _documentText.length) {
      segments.add(_TextSegment.plain(_documentText.substring(lastEnd)));
    }

    final filledCount = filledValues.values.where((v) => v.isNotEmpty).length;
    final totalFields = automations.length;
    final allFilled = filledCount == totalFields;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: allFilled
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: allFilled ? AppColors.success : AppColors.accent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                allFilled ? Icons.check_circle : Icons.info_outline,
                size: 20,
                color: allFilled ? AppColors.success : AppColors.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      allFilled ? 'Todos los campos completados' : 'Campos incompletos',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: allFilled ? AppColors.success : AppColors.accent,
                      ),
                    ),
                    Text(
                      '$filledCount de $totalFields campos listos',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
        SelectableText.rich(
          TextSpan(
            children: segments.map((seg) {
              if (seg.isReplaced) {
                return TextSpan(
                  text: seg.displayValue,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    height: 1.8,
                    fontWeight: FontWeight.bold,
                    color: seg.hasValue ? AppColors.primary : AppColors.error,
                    backgroundColor: seg.hasValue
                        ? AppColors.accent.withValues(alpha: 0.2)
                        : AppColors.error.withValues(alpha: 0.1),
                  ),
                );
              } else {
                return TextSpan(
                  text: seg.text,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    height: 1.8,
                    color: AppColors.onSurface,
                    letterSpacing: 0.1,
                  ),
                );
              }
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) {
      return const Scaffold(
        body: LoadingIndicator(message: 'Cargando revisión...'),
      );
    }

    final template = _data!['template'] as Map<String, dynamic>;
    final automations =
        (_data!['automations'] as List<dynamic>).cast<Map<String, dynamic>>();
    final filledValues =
        (_data!['filledValues'] as Map<String, dynamic>).cast<String, String>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PremiumHeader(
            title: 'Revisar Documento',
            subtitle: '${template['name']} — Verifica los datos',
            showBackButton: true,
          ),
          Expanded(
            child: _isLoadingDoc
                ? const LoadingIndicator(message: 'Cargando documento...')
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                    child: Center(
                      child: PremiumCard(
                        width: 850,
                        padding: const EdgeInsets.all(60),
                        color: Colors.white,
                        shadows: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ],
                        child: _buildDocumentWithReplacements(
                            automations, filledValues),
                      ),
                    ),
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
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Editar Campos'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    text: _isGenerating ? 'Generando...' : 'Generar y Descargar .docx',
                    icon: _isGenerating ? null : Icons.download_done_rounded,
                    isLoading: _isGenerating,
                    onPressed: _isGenerating ? null : () => _generateDocument(),
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

class _TextSegment {
  final String text;
  final String displayValue;
  final bool isReplaced;
  final bool hasValue;

  _TextSegment.plain(this.text)
      : displayValue = text,
        isReplaced = false,
        hasValue = false;

  _TextSegment.replaced(this.text, this.displayValue, this.hasValue)
      : isReplaced = true;
}
