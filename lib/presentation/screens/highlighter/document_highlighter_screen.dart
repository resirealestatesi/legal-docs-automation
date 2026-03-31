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
  TextSelection? _currentSelection;
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

  void _onSelectionComplete() {
    final selection = _currentSelection;
    if (selection != null && !selection.isCollapsed) {
      final text = selection.textInside(_documentText);
      if (text.trim().isNotEmpty) {
        _showHighlightDialog(
          text,
          selection.start,
          selection.end,
        );
      }
    }
    setState(() => _currentSelection = null);
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

  void _showHighlightDialog(String selectedText, int start, int end) {
    final nameController = TextEditingController();
    final List<String> options = [];
    final optionController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text('Asignar Campo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
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
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: nameController,
                  labelText: 'Nombre del campo',
                  hintText: 'Ej: Fecha de Contrato',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Opciones (Dropdown):',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: optionController,
                        hintText: 'Agregar opción',
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        if (optionController.text.trim().isNotEmpty) {
                          setDialogState(() {
                            options.add(optionController.text.trim());
                            optionController.clear();
                          });
                        }
                      },
                    ),
                  ],
                ),
                ...options.map(
                  (o) => ListTile(
                    dense: true,
                    title: Text(o),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: AppColors.error,
                        size: 20,
                      ),
                      onPressed: () {
                        setDialogState(() => options.remove(o));
                      },
                    ),
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
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  final highlight = HighlightSelection(
                    templateId: _templateId,
                    fieldName: nameController.text.trim(),
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
              child: const Text('Guardar'),
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
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Selecciona texto en el documento para resaltarlo',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
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
                      onTap: () {
                        _currentSelection = _textController.selection;
                        if (_currentSelection != null &&
                            !_currentSelection!.isCollapsed) {
                          _onSelectionComplete();
                        }
                      },
                    ),
                  ),
                ),
                if (_highlights.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Campos resaltados (${_highlights.length})',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 60,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _highlights.length,
                            itemBuilder: (ctx, i) {
                              final h = _highlights[i];
                              return Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                constraints: const BoxConstraints(
                                  maxWidth: 200,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.highlight,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.accent.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        h.fieldName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        h.highlightText,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
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
