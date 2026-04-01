import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../data/datasources/remote/supabase_datasource.dart';
import '../../../services/docx_service.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/premium_card.dart';
import '../../widgets/common/premium_header.dart';

final automationsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, templateId) async {
  final supabase = Supabase.instance.client;
  final datasource = SupabaseDatasource(supabase);
  return datasource.getAutomationsByTemplateId(templateId);
});

class TemplateFillScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? template;
  final String? initialDocumentText;
  const TemplateFillScreen({super.key, this.template, this.initialDocumentText});

  @override
  ConsumerState<TemplateFillScreen> createState() => _TemplateFillScreenState();
}

class _TemplateFillScreenState extends ConsumerState<TemplateFillScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _dropdownValues = {};
  Map<String, dynamic>? _template;
  String _documentText = '';
  bool _isLoadingDoc = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Check if template is passed via constructor (testing/direct navigation)
    if (widget.template != null && _template == null) {
      _template = widget.template;
    } 
    // Otherwise fallback to GoRouterState
    else if (_template == null) {
       _template = GoRouterState.of(context).extra as Map<String, dynamic>?;
    }

    if (_template != null && _documentText.isEmpty && !_isLoadingDoc) {
      if (widget.initialDocumentText != null) {
        _documentText = widget.initialDocumentText!;
      } else {
        _loadDocumentText();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDocumentText() async {
    if (_template == null) return;
    final fileUrl = _template!['file_url'] as String?;
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

  TextEditingController _getController(String key) {
    return _controllers.putIfAbsent(key, () => TextEditingController());
  }

  String _getValue(String autoId) {
    return _dropdownValues[autoId] ?? _controllers[autoId]?.text ?? '';
  }

  void _goToReview(List<Map<String, dynamic>> automations) {
    final filledValues = <String, String>{};
    for (final auto in automations) {
      filledValues[auto['id'] as String] = _getValue(auto['id'] as String);
    }

    context.push('/review', extra: {
      'template': _template,
      'automations': automations,
      'filledValues': filledValues,
    });
  }

  void _showFieldEditor(Map<String, dynamic> auto, List<String> options) {
    final autoId = auto['id'] as String;
    final fieldName = auto['field_name'] as String;
    final isUppercase = auto['uppercase'] == true;
    final currentValue = _getValue(autoId);

    if (options.isNotEmpty) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(fieldName, style: AppTextStyles.headlineH3),
              const SizedBox(height: 8),
              Text('Selecciona una opción', style: AppTextStyles.bodySmall),
              const SizedBox(height: 24),
              ...options.map((o) => PremiumCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.zero,
                    color: _getValue(autoId) == o 
                        ? AppColors.primary 
                        : null,
                    onTap: () {
                      setState(() => _dropdownValues[autoId] = o);
                      Navigator.pop(ctx);
                    },
                    child: ListTile(
                      title: Text(
                        isUppercase ? o.toUpperCase() : o,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: _getValue(autoId) == o ? Colors.white : null,
                          fontWeight: _getValue(autoId) == o ? FontWeight.bold : null,
                        ),
                      ),
                      trailing: _getValue(autoId) == o
                          ? const Icon(Icons.check_circle_rounded, color: Colors.white)
                          : const Icon(Icons.circle_outlined, size: 20),
                    ),
                  )),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    } else {
      final controller = _getController(autoId);
      controller.text = currentValue;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
             decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(fieldName, style: AppTextStyles.headlineH3),
                const SizedBox(height: 8),
                Text(
                  isUppercase ? 'Este campo se convertirá a MAYÚSCULAS' : 'Ingresa la información solicitada',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isUppercase ? AppColors.accent : null,
                  ),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  controller: controller,
                  hintText: 'Escribe aquí...',
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {});
                      Navigator.pop(ctx);
                    },
                    child: const Text('Confirmar'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildDocumentView(List<Map<String, dynamic>> automations) {
    if (_isLoadingDoc) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Extrayendo texto...'),
          ],
        ),
      );
    }

    if (_documentText.isEmpty) {
      return const Center(child: Text('Cargando documento...'));
    }

    final placeholderMap = <String, Map<String, dynamic>>{};
    for (final auto in automations) {
      placeholderMap[auto['highlight_text'] as String] = auto;
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
      final auto = placeholderMap[placeholder];
      segments.add(_TextSegment.placeholder(placeholder, auto));
      lastEnd = match.end;
    }
    if (lastEnd < _documentText.length) {
      segments.add(_TextSegment.plain(_documentText.substring(lastEnd)));
    }

    return SelectableText.rich(
      TextSpan(
        children: segments.map((seg) {
          if (seg.isPlaceholder && seg.auto != null) {
            final autoId = seg.auto!['id'] as String;
            final value = _getValue(autoId);
            final hasValue = value.isNotEmpty;
            final isUppercase = seg.auto!['uppercase'] == true;
            final displayText = hasValue
                ? (isUppercase ? value.toUpperCase() : value)
                : seg.text;
            final options = (seg.auto!['field_options'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];

            return WidgetSpan(
              child: GestureDetector(
                onTap: () => _showFieldEditor(seg.auto!, options),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: hasValue
                        ? AppColors.accent.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: hasValue
                          ? AppColors.accent
                          : AppColors.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    displayText,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: hasValue ? FontWeight.bold : FontWeight.w500,
                      color: hasValue ? AppColors.primary : AppColors.accent,
                    ),
                  ),
                ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_template == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final automationsAsync = ref.watch(automationsProvider(_template!['id']));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PremiumHeader(
            title: _template!['name'] ?? 'Llenar Plantilla',
            subtitle: 'Completa la información necesaria',
            showBackButton: true,
          ),
          Expanded(
            child: automationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
              data: (automations) {
                return Stack(
                  children: [
                    SingleChildScrollView(
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
                          child: _buildDocumentView(automations),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 32,
                      right: 32,
                      child: FloatingActionButton.extended(
                        onPressed: () => _goToReview(automations),
                        backgroundColor: AppColors.primary,
                        icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                        label: const Text('Revisar y Generar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TextSegment {
  final String text;
  final Map<String, dynamic>? auto;
  final bool isPlaceholder;

  _TextSegment.plain(this.text)
      : auto = null,
        isPlaceholder = false;

  _TextSegment.placeholder(this.text, this.auto) : isPlaceholder = true;
}

