import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../data/datasources/remote/supabase_datasource.dart';
import '../../../domain/entities/highlight_selection.dart';
import '../../../services/docx_service.dart';
import '../../providers/highlight_provider.dart';
import '../../providers/company_provider.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/premium_card.dart';
import '../../widgets/common/premium_header.dart';

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
  String _fileName = 'Documento sin nombre';
  Uint8List? _fileBytes;
  final List<HighlightSelection> _highlights = [];
  String? _existingTemplateId;
  late String _sessionTemplateId;
  bool _isLoading = true;
  bool _fileLoaded = false;
  late final HighlightingTextController _textController;

  @override
  void initState() {
    super.initState();
    _textController = HighlightingTextController(
      highlights: _highlights,
      baseStyle: GoogleFonts.inter(
        fontSize: 16,
        height: 1.8,
        color: AppColors.onSurface,
        letterSpacing: 0.2,
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fileLoaded) {
      final extra = GoRouterState.of(context).extra;
      if (extra is PlatformFile) {
        _fileLoaded = true;
        _sessionTemplateId = const Uuid().v4();
        _loadDocument(extra);
      } else if (extra is Map<String, dynamic>) {
        _fileLoaded = true;
        final template = extra['template'] as Map<String, dynamic>;
        _sessionTemplateId = template['id'].toString();
        _loadExistingTemplate(extra);
      }
    }
  }

  Future<void> _loadDocument(PlatformFile file) async {
    setState(() {
      _fileName = file.name;
      _isLoading = true;
    });

    try {
      if (file.path != null || file.bytes != null) {
        dynamic doc;
        if (file.path != null) {
          doc = await DocxReader.load(file.path!);
        } else {
          final dir = await getTemporaryDirectory();
          final tempFile = File('${dir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.docx');
          await tempFile.writeAsBytes(file.bytes!);
          doc = await DocxReader.load(tempFile.path);
        }
        
        _processDocx(doc, file.bytes);

        setState(() => _isLoading = false);
      } else {
        throw Exception('El archivo no tiene datos válidos.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _documentText = 'Error al leer el documento: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadExistingTemplate(Map<String, dynamic> data) async {
    final template = data['template'] as Map<String, dynamic>;
    final automations = (data['automations'] as List<dynamic>).cast<Map<String, dynamic>>();

    setState(() {
      _existingTemplateId = template['id'].toString();
      _fileName = template['name'];
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final datasource = SupabaseDatasource(supabase);

      final fileUrl = template['file_url'] as String?;
      if (fileUrl == null) throw Exception('No hay archivo en la plantilla.');

      final bytes = await datasource.downloadDocxFile(fileUrl);
      final dir = await getTemporaryDirectory();
      final tempFile = File('${dir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.docx');
      await tempFile.writeAsBytes(bytes);

      var doc = await DocxReader.load(tempFile.path);
      _processDocx(doc, bytes);

      for (final auto in automations) {
        final highlightText = auto['highlight_text'] as String? ?? '';
        
        // Dynamically find the correct start and end offsets since the DOCX text
        // might have shifted during previous placeholder replacements.
        int dynStart = _documentText.indexOf(highlightText);
        int dynEnd = dynStart >= 0 ? dynStart + highlightText.length : 0;

        if (dynStart == -1) {
          dynStart = auto['position_start'] ?? 0;
          dynEnd = math.max(dynStart, auto['position_end'] ?? 0);
        }

        _highlights.add(HighlightSelection(
          templateId: _existingTemplateId!,
          fieldName: auto['field_name'],
          highlightText: highlightText,
          startOffset: dynStart,
          endOffset: dynEnd,
          colorHex: auto['highlight_color'] ?? '#B89B5E',
          options: (auto['field_options']?['options'] as List<dynamic>?)?.cast<String>() ?? [],
          uppercase: auto['uppercase'] == true,
          createdAt: DateTime.tryParse(auto['created_at'] ?? '') ?? DateTime.now(),
        ));
      }

      _textController.refresh();
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _documentText = 'Error al cargar plantilla: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _processDocx(doc, Uint8List? bytes) {
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

    if (bytes != null) _fileBytes = bytes;
    _documentText = buffer.toString();
    _textController.text = _documentText;
  }

  Future<void> _saveTemplate() async {
    final company = ref.read(currentCompanyProvider).value;
    if (company == null) return;

    if (_highlights.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes resaltar al menos un campo para automatizar.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final datasource = SupabaseDatasource(supabase);
      final docxService = DocxService();

      final templateName = _fileName.replaceAll('.docx', '');
      final uploadId = _existingTemplateId ?? const Uuid().v4();
      
      final updatedHighlights = <HighlightSelection>[];
      for (final highlight in _highlights) {
        final sanitizedName = highlight.fieldName
            .replaceAll(RegExp(r'[\[\]]'), '')
            .replaceAll(' ', '_')
            .toUpperCase();
        final placeholder = '{{$sanitizedName}}';
        
        updatedHighlights.add(highlight.copyWith(
          highlightText: placeholder,
          templateId: uploadId,
        ));
      }

      Uint8List? finalFileBytes = _fileBytes;
      if (_fileBytes != null && _highlights.isNotEmpty) {
        finalFileBytes = await docxService.replaceRangesInDocument(
          _fileBytes!,
          updatedHighlights,
        );
      }

      String? fileUrl;
      if (finalFileBytes != null) {
        fileUrl = await datasource.uploadDocxFile(
          templateId: uploadId,
          fileBytes: finalFileBytes,
          fileName: _fileName,
        );
      }

      String finalTemplateId;
      if (_existingTemplateId != null) {
        await datasource.updateTemplate(
          id: _existingTemplateId!,
          name: templateName,
          description: 'Plantilla editada con ${_highlights.length} campos',
          fileUrl: fileUrl,
        );
        await datasource.deleteAutomationsByTemplateId(_existingTemplateId!);
        finalTemplateId = _existingTemplateId!;
      } else {
        final template = await datasource.createTemplate(
          companyId: company.id,
          name: templateName,
          description: 'Plantilla con ${_highlights.length} campos',
          fileUrl: fileUrl,
        );
        finalTemplateId = template['id'].toString();
      }

      for (final highlight in updatedHighlights) {
        await datasource.createAutomation(
          templateId: finalTemplateId,
          fieldName: highlight.fieldName,
          highlightText: highlight.highlightText,
          highlightColor: highlight.colorHex,
          fieldOptions: highlight.options,
          uppercase: highlight.uppercase,
          positionStart: highlight.startOffset,
          positionEnd: highlight.endOffset,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Plantilla "$templateName" ${_existingTemplateId != null ? 'actualizada' : 'guardada'} con ${_highlights.length} campos',
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar plantilla: $e')),
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
    bool uppercase = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.highlight_alt, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Asignar Campo', style: AppTextStyles.headlineH3),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PremiumCard(
                  padding: const EdgeInsets.all(12),
                  color: AppColors.accent.withValues(alpha: 0.05),
                  border: BorderSide(color: AppColors.accent.withValues(alpha: 0.1)),
                  child: Text(
                    selectedText,
                    style: AppTextStyles.bodySemiBold.copyWith(fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    prefixIcon: Icon(Icons.category_rounded, size: 20),
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
                  hintText: 'Ej: Representante Legal',
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('Opciones:', style: AppTextStyles.bodySemiBold),
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
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Agregar'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AppTextField(
                  controller: optionController,
                  hintText: 'Ej: Opción 1',
                ),
                if (options.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: options.map((o) => Chip(
                        label: Text(o, style: const TextStyle(fontSize: 12)),
                        onDeleted: () => setDialogState(() => options.remove(o)),
                        backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        side: BorderSide.none,
                      )).toList(),
                    ),
                  ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: uppercase,
                  onChanged: (val) => setDialogState(() => uppercase = val ?? false),
                  title: Text('Forzar MAYÚSCULAS', style: AppTextStyles.bodyMedium),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.accent,
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
                    templateId: _sessionTemplateId,
                    fieldName: '[$category] ${nameController.text.trim()}',
                    highlightText: selectedText,
                    startOffset: start,
                    endOffset: end,
                    options: options,
                    uppercase: uppercase,
                    createdAt: DateTime.now(),
                  );
                  setState(() => _highlights.add(highlight));
                  _textController.refresh();
                  ref.read(highlightListProvider.notifier).addHighlight(highlight);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Asignar Campo'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          PremiumHeader(
            title: 'Editar Plantilla',
            subtitle: _fileName,
            showBackButton: true,
            actions: [
              if (_highlights.isNotEmpty)
                TextButton.icon(
                  onPressed: _saveTemplate,
                  icon: const Icon(Icons.save_rounded, color: Colors.white, size: 20),
                  label: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: AppColors.background,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                      child: Center(
                        child: PremiumCard(
                          width: 800,
                          padding: const EdgeInsets.all(48),
                          color: Colors.white,
                          shadows: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                          child: TextField(
                            controller: _textController,
                            readOnly: true,
                            maxLines: null,
                            style: _textController.baseStyle,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              fillColor: Colors.transparent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 24,
                    left: 24,
                    right: 24,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PremiumCard(
                          margin: EdgeInsets.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: AppColors.primary,
                          shadows: [
                             BoxShadow(
                               color: AppColors.primary.withValues(alpha: 0.3),
                               blurRadius: 20,
                               offset: const Offset(0, 10),
                             ),
                          ],
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Resalta texto en el documento',
                                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
                              ),
                              const SizedBox(width: 16),
                              Container(width: 1, height: 24, color: Colors.white24),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  final selection = _textController.selection;
                                  if (!selection.isCollapsed) {
                                    final text = selection.textInside(_documentText);
                                    if (text.trim().isNotEmpty) {
                                      _showAssignDialog(text, selection.start, selection.end);
                                    }
                                  } else {
                                     ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Selecciona texto primero')),
                                      );
                                  }
                                },
                                icon: const Icon(Icons.add_rounded, size: 20),
                                label: const Text('Asignar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(100, 40),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
           if (_highlights.isNotEmpty)
            _HighlightsFooter(
              highlights: _highlights,
              onDelete: (i) => setState(() {
                _highlights.removeAt(i);
                _textController.refresh();
              }),
              onClear: () => setState(() {
                _highlights.clear();
                _textController.refresh();
              }),
            ),
        ],
      ),
    );
  }
}

class HighlightingTextController extends TextEditingController {
  final List<HighlightSelection> highlights;
  final TextStyle baseStyle;

  HighlightingTextController({
    super.text,
    required this.highlights,
    required this.baseStyle,
  });

  void refresh() {
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (highlights.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style ?? baseStyle,
        withComposing: withComposing,
      );
    }

    final List<TextSpan> spans = [];
    int lastOffset = 0;

    final sortedHighlights = List<HighlightSelection>.from(highlights)
      ..sort((a, b) => a.startOffset.compareTo(b.startOffset));

    for (final highlight in sortedHighlights) {
      if (highlight.startOffset < lastOffset) continue;

      if (highlight.startOffset > lastOffset) {
        final preText = text.substring(
          lastOffset,
          highlight.startOffset.clamp(0, text.length),
        );
        spans.add(TextSpan(text: preText));
      }

      final hEnd = highlight.endOffset.clamp(0, text.length);
      final hStart = highlight.startOffset.clamp(0, text.length);

      if (hStart < hEnd) {
        final highlightedText = text.substring(hStart, hEnd);
        final color = _parseColor(highlight.colorHex).withValues(alpha: 0.3);
        
        spans.add(TextSpan(
          text: highlightedText,
          style: (style ?? baseStyle).copyWith(
            backgroundColor: color,
            fontWeight: FontWeight.bold,
          ),
        ));
        lastOffset = math.max(lastOffset, hEnd);
      } else {
        lastOffset = math.max(lastOffset, hStart);
      }
    }

    if (lastOffset < text.length) {
      spans.add(TextSpan(text: text.substring(lastOffset)));
    }

    return TextSpan(children: spans, style: style ?? baseStyle);
  }

  Color _parseColor(String hex) {
    try {
      String cleanHex = hex.replaceFirst('#', '');
      if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return Colors.yellow;
    }
  }
}

class _HighlightsFooter extends StatelessWidget {
  final List<HighlightSelection> highlights;
  final Function(int) onDelete;
  final VoidCallback onClear;

  const _HighlightsFooter({
    required this.highlights,
    required this.onDelete,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : Colors.white,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Row(
              children: [
                Text(
                  'CAMPOS DETECTADOS (${highlights.length})',
                  style: AppTextStyles.captionLabel,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onClear,
                  child: Text(
                    'Limpiar todo',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: highlights.length,
              itemBuilder: (ctx, i) {
                final h = highlights[i];
                return PremiumCard(
                  width: 220,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  color: AppColors.accent.withValues(alpha: 0.05),
                  border: BorderSide(color: AppColors.accent.withValues(alpha: 0.15)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              h.fieldName,
                              style: AppTextStyles.bodySemiBold.copyWith(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => onDelete(i),
                            child: const Icon(Icons.cancel_outlined, size: 16, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '"${h.highlightText}"',
                        style: AppTextStyles.bodySmall.copyWith(fontStyle: FontStyle.italic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
