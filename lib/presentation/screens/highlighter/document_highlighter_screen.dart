import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../config/theme/app_colors.dart';
import '../../../data/datasources/remote/supabase_datasource.dart';
import '../../../domain/entities/highlight_selection.dart';
import '../../providers/highlight_provider.dart';
import '../../providers/company_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';

const _fieldCategories = [
  'Fecha',
  'Monto',
  'Nombre',
  'Dirección',
  'Empresa',
  'Documento',
  'Firma',
  'Otro',
];

class DocumentHighlighterScreen extends ConsumerStatefulWidget {
  const DocumentHighlighterScreen({super.key});

  @override
  ConsumerState<DocumentHighlighterScreen> createState() =>
      _DocumentHighlighterScreenState();
}

class _DocumentHighlighterScreenState
    extends ConsumerState<DocumentHighlighterScreen> {
  String _documentText = '';
  String _fileName = '';
  final List<HighlightSelection> _highlights = [];
  final _templateId = const Uuid().v4();
  bool _isLoading = true;
  bool _fileLoaded = false;
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fileLoaded) {
      final file = GoRouterState.of(context).extra as PlatformFile?;
      if (file != null) {
        _fileLoaded = true;
        _loadDocument(file);
      }
    }
  }

  Future<void> _loadDocument(PlatformFile file) async {
    setState(() {
      _fileName = file.name;
      _isLoading = true;
    });

    try {
      if (file.path != null) {
        final doc = await DocxReader.load(file.path!);
        final buffer = StringBuffer();
        for (final element in doc.elements) {
          if (element is DocxParagraph) {
            for (final child in element.children) {
              if (child is DocxText) {
                buffer.write(child.content);
              }
            }
            buffer.writeln();
          }
        }

        setState(() {
          _documentText = buffer.toString();
          _textController.text = _documentText;
          _isLoading = false;
        });
      } else {
        setState(() {
          _documentText = 'No se pudo cargar el documento.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _documentText = 'Error al leer el documento: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveTemplate() async {
    final company = ref.read(currentCompanyProvider).value;
    if (company == null) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final datasource = SupabaseDatasource(supabase);

      final templateName = _fileName.replaceAll('.docx', '');

      final template = await datasource.createTemplate(
        companyId: company.id,
        name: templateName,
        description: 'Plantilla con ${_highlights.length} campos',
      );

      final templateId = template['id'] as String;

      for (final highlight in _highlights) {
        await datasource.createAutomation(
          templateId: templateId,
          fieldName: highlight.fieldName,
          highlightText: highlight.highlightText,
          fieldOptions: highlight.options,
          positionStart: highlight.startOffset,
          positionEnd: highlight.endOffset,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Plantilla "$templateName" guardada con ${_highlights.length} campos',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAssignDialog(String selectedText, int start, int end) {
    final nameController = TextEditingController();
    String category = _fieldCategories.first;
    final List<String> options = [];
    final optionController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(Icons.highlight_alt, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              const Text('Asignar Campo', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.highlight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '"$selectedText"',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      fontSize: 14,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: _fieldCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => category = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: nameController,
                  labelText: 'Nombre del campo',
                  hintText: 'Ej: Fecha de Contrato',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Opciones:',
                        style: TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 13)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        if (optionController.text.trim().isNotEmpty) {
                          setDialogState(() {
                            options.add(optionController.text.trim());
                            optionController.clear();
                          });
                        }
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Agregar'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: optionController,
                        hintText: 'Escribe opción y presiona Agregar',
                      ),
                    ),
                  ],
                ),
                if (options.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: options
                          .map(
                            (o) => Chip(
                              label:
                                  Text(o, style: const TextStyle(fontSize: 12)),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () {
                                setDialogState(() => options.remove(o));
                              },
                              backgroundColor: AppColors.highlight,
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  final highlight = HighlightSelection(
                    templateId: _templateId,
                    fieldName: '[$category] ${nameController.text.trim()}',
                    highlightText: selectedText,
                    startOffset: start,
                    endOffset: end,
                    options: options,
                    createdAt: DateTime.now(),
                  );

                  setState(() => _highlights.add(highlight));
                  ref
                      .read(highlightListProvider.notifier)
                      .addHighlight(highlight);

                  Navigator.pop(ctx);
                }
              },
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Asignar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_fileName.isNotEmpty ? _fileName : 'Documento'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: AppColors.primary.withValues(alpha: 0.05),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Selecciona texto y presiona "Asignar"',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          final selection = _textController.selection;
                          if (!selection.isCollapsed) {
                            final text = selection.textInside(_documentText);
                            if (text.trim().isNotEmpty) {
                              _showAssignDialog(
                                text,
                                selection.start,
                                selection.end,
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Selecciona texto primero'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.highlight_alt, size: 18),
                        label: const Text('Asignar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          minimumSize: const Size(0, 0),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _textController,
                      readOnly: true,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: AppColors.onSurface,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
                if (_highlights.isNotEmpty) ...[
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          'Campos (${_highlights.length})',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setState(() => _highlights.clear());
                          },
                          child: const Text('Limpiar todo',
                              style: TextStyle(
                                  color: AppColors.error, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _highlights.length,
                      itemBuilder: (ctx, i) {
                        final h = _highlights[i];
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          constraints: const BoxConstraints(maxWidth: 180),
                          decoration: BoxDecoration(
                            color: AppColors.highlight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      h.fieldName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() => _highlights.removeAt(i));
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(Icons.close,
                                          size: 14, color: AppColors.error),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '"${h.highlightText}"',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: AppButton(
                    text: 'Guardar Plantilla',
                    icon: Icons.save_rounded,
                    onPressed:
                        _highlights.isEmpty ? null : () => _saveTemplate(),
                  ),
                ),
              ],
            ),
    );
  }
}
