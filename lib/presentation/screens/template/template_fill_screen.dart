import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:docx_creator/docx_creator.dart';
import '../../../config/theme/app_colors.dart';
import '../../../data/datasources/remote/supabase_datasource.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/loading_indicator.dart';

final automationsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, templateId) async {
  final supabase = Supabase.instance.client;
  final datasource = SupabaseDatasource(supabase);
  return datasource.getAutomationsByTemplateId(templateId);
});

class TemplateFillScreen extends ConsumerStatefulWidget {
  const TemplateFillScreen({super.key});

  @override
  ConsumerState<TemplateFillScreen> createState() => _TemplateFillScreenState();
}

class _TemplateFillScreenState extends ConsumerState<TemplateFillScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _dropdownValues = {};
  bool _isGenerating = false;
  Map<String, dynamic>? _template;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final template = GoRouterState.of(context).extra as Map<String, dynamic>?;
    if (template != null && _template == null) {
      setState(() => _template = template);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getController(String key) {
    return _controllers.putIfAbsent(key, () => TextEditingController());
  }

  Future<void> _generateDocument(List<Map<String, dynamic>> automations) async {
    if (_template == null) return;

    setState(() => _isGenerating = true);

    try {
      final builder = DocxDocumentBuilder();

      builder.h1(_template!['name'] ?? 'Documento');
      builder.p('');

      for (final auto in automations) {
        final fieldName = auto['field_name'] as String;
        final highlightText = auto['highlight_text'] as String;

        final value = _dropdownValues[auto['id']] ??
            _controllers[auto['id']]?.text ??
            highlightText;

        builder.add(DocxParagraph(children: [
          DocxText('$fieldName: ',
              fontWeight: DocxFontWeight.bold, fontSize: 12),
          DocxText(value, fontSize: 12),
        ]));
      }

      final doc = builder.build();

      final dir = await getTemporaryDirectory();
      final fileName = '${_template!['name'] ?? 'documento'}_llenado.docx';
      final filePath = '${dir.path}/$fileName';

      await DocxExporter().exportToFile(doc, filePath);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(filePath)]),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documento generado exitosamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar documento: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_template == null) {
      return const Scaffold(
        body: LoadingIndicator(message: 'Cargando plantilla...'),
      );
    }

    final automationsAsync = ref.watch(automationsProvider(_template!['id']));

    return Scaffold(
      appBar: AppBar(
        title: Text(_template!['name'] ?? 'Llenar Plantilla'),
      ),
      body: automationsAsync.when(
        loading: () => const LoadingIndicator(message: 'Cargando campos...'),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Error: $error'),
            ],
          ),
        ),
        data: (automations) {
          if (automations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    'Esta plantilla no tiene campos configurados',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AppColors.primary.withValues(alpha: 0.05),
                child: Row(
                  children: [
                    const Icon(Icons.edit_note,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Llena los ${automations.length} campos del documento',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: automations.length,
                  itemBuilder: (ctx, i) {
                    final auto = automations[i];
                    final fieldName = auto['field_name'] as String;
                    final highlightText = auto['highlight_text'] as String;
                    final options = (auto['field_options'] as List<dynamic>?)
                            ?.map((e) => e.toString())
                            .toList() ??
                        [];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fieldName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.highlight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Original: "$highlightText"',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (options.isNotEmpty)
                              DropdownButtonFormField<String>(
                                value: _dropdownValues[auto['id']],
                                decoration: const InputDecoration(
                                  labelText: 'Seleccionar valor',
                                ),
                                items: options
                                    .map((o) => DropdownMenuItem(
                                        value: o, child: Text(o)))
                                    .toList(),
                                onChanged: (val) {
                                  setState(() =>
                                      _dropdownValues[auto['id']] = val ?? '');
                                },
                              )
                            else
                              AppTextField(
                                controller: _getController(auto['id']),
                                hintText: 'Escribe el valor real',
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppButton(
                  text: _isGenerating
                      ? 'Generando...'
                      : 'Generar Documento .docx',
                  icon: _isGenerating ? null : Icons.download_rounded,
                  isLoading: _isGenerating,
                  onPressed: _isGenerating
                      ? null
                      : () => _generateDocument(automations),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
