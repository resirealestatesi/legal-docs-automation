import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/supabase_config.dart';
import '../../providers/company_provider.dart';
import '../../providers/sync_provider.dart';
import '../../widgets/common/loading_indicator.dart';

final templatesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, companyId) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from(SupabaseConfig.templatesTable)
      .select()
      .eq('company_id', companyId)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _companyId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final company = ref.read(currentCompanyProvider).value;
      if (company != null) {
        setState(() => _companyId = company.id);
        _syncOnStart();
      }
    });
  }

  Future<void> _syncOnStart() async {
    final company = ref.read(currentCompanyProvider).value;
    if (company != null) {
      try {
        await ref.read(syncProvider).syncForCompany(company.id);
      } catch (_) {}
    }
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
      withData: true,
    );

    if (result != null && result.files.single.path != null) {
      await context.push('/highlight', extra: result.files.single);
      if (mounted && _companyId != null) {
        ref.invalidate(templatesProvider(_companyId!));
      }
    }
  }

  Future<void> _deleteTemplate(String templateId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text('Eliminar plantilla'),
        content: Text(
          '¿Eliminar "$name"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && _companyId != null) {
      try {
        final supabase = Supabase.instance.client;
        await supabase
            .from(SupabaseConfig.automationsTable)
            .delete()
            .eq('template_id', templateId);
        await supabase
            .from(SupabaseConfig.templatesTable)
            .delete()
            .eq('id', templateId);

        ref.invalidate(templatesProvider(_companyId!));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Plantilla eliminada')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _editTemplate(Map<String, dynamic> template) async {
    final nameController = TextEditingController(text: template['name']);
    final descController =
        TextEditingController(text: template['description'] ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text('Editar Plantilla'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result == true && _companyId != null) {
      try {
        final supabase = Supabase.instance.client;
        await supabase.from(SupabaseConfig.templatesTable).update({
          'name': nameController.text.trim(),
          'description': descController.text.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', template['id']);

        ref.invalidate(templatesProvider(_companyId!));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Plantilla actualizada')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _shareTemplate(Map<String, dynamic> template) async {
    try {
      final supabase = Supabase.instance.client;
      final automations = await supabase
          .from(SupabaseConfig.automationsTable)
          .select()
          .eq('template_id', template['id']);

      final exportData = {
        'template': template,
        'automations': automations,
        'exported_at': DateTime.now().toIso8601String(),
      };

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${template['name'] ?? 'plantilla'}.json');
      await file.writeAsString(jsonEncode(exportData));

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)]),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir: $e')),
        );
      }
    }
  }

  Future<void> _importTemplate() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      final templateData = data['template'] as Map<String, dynamic>;
      final automationsData = data['automations'] as List<dynamic>;

      final company = ref.read(currentCompanyProvider).value;
      if (company == null) return;

      final supabase = Supabase.instance.client;

      final newTemplate = await supabase
          .from(SupabaseConfig.templatesTable)
          .insert({
            'company_id': company.id,
            'name': '${templateData['name']} (importada)',
            'description': templateData['description'],
          })
          .select()
          .single();

      for (final auto in automationsData) {
        await supabase.from(SupabaseConfig.automationsTable).insert({
          'template_id': newTemplate['id'],
          'field_name': auto['field_name'],
          'highlight_text': auto['highlight_text'],
          'highlight_color': auto['highlight_color'],
          'field_options': auto['field_options'],
        });
      }

      ref.invalidate(templatesProvider(company.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plantilla importada exitosamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al importar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyState = ref.watch(currentCompanyProvider);
    final company = companyState.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LegalDocs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () {
              ref.read(currentCompanyProvider.notifier).logout();
              context.go('/access');
            },
          ),
        ],
      ),
      body: company == null
          ? const LoadingIndicator(message: 'Cargando...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Icon(Icons.business, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  company.name,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  'Código: ${company.code}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Acciones',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  _ActionCard(
                    icon: Icons.upload_file_rounded,
                    title: 'Cargar Documento .docx',
                    subtitle: 'Selecciona un documento para resaltar campos',
                    onTap: _pickDocument,
                  ),
                  const SizedBox(height: 12),
                  _ActionCard(
                    icon: Icons.upload_rounded,
                    title: 'Importar Plantilla',
                    subtitle: 'Cargar plantilla desde archivo JSON',
                    onTap: _importTemplate,
                  ),
                  const SizedBox(height: 12),
                  _ActionCard(
                    icon: Icons.sync_rounded,
                    title: 'Sincronizar',
                    subtitle: 'Descargar últimas plantillas de Supabase',
                    onTap: () async {
                      try {
                        await ref.read(syncProvider).syncForCompany(company.id);
                        ref.invalidate(templatesProvider(company.id));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Sincronización completada')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Mis Plantillas',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  _TemplatesList(
                    companyId: company.id,
                    onEdit: _editTemplate,
                    onDelete: _deleteTemplate,
                    onShare: _shareTemplate,
                    onFill: (template) {
                      context.push('/fill', extra: template);
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class _TemplatesList extends ConsumerWidget {
  final String companyId;
  final Function(Map<String, dynamic>) onEdit;
  final Function(String, String) onDelete;
  final Function(Map<String, dynamic>) onShare;
  final Function(Map<String, dynamic>) onFill;

  const _TemplatesList({
    required this.companyId,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
    required this.onFill,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(templatesProvider(companyId));

    return templatesAsync.when(
      loading: () => const LoadingIndicator(message: 'Cargando plantillas...'),
      error: (error, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error: $error'),
        ),
      ),
      data: (templates) {
        if (templates.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.description_outlined,
                        size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    Text(
                      'No hay plantillas guardadas',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Carga un .docx y resalta campos para crear una',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Column(
          children: templates.map((template) {
            return Card(
              child: ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.description, color: AppColors.accent),
                ),
                title: Text(template['name'] ?? 'Sin nombre'),
                subtitle: Text(
                  template['description'] ?? 'Sin descripción',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => onFill(template),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      color: AppColors.textSecondary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'fill':
                        onFill(template);
                        break;
                      case 'edit':
                        onEdit(template);
                        break;
                      case 'share':
                        onShare(template);
                        break;
                      case 'delete':
                        onDelete(template['id'], template['name'] ?? '');
                        break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'fill',
                      child: Row(
                        children: [
                          Icon(Icons.edit_note,
                              color: AppColors.primary, size: 20),
                          SizedBox(width: 8),
                          Text('Llenar campos'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined,
                              color: AppColors.accent, size: 20),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share_outlined,
                              color: AppColors.textSecondary, size: 20),
                          SizedBox(width: 8),
                          Text('Compartir'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              color: AppColors.error, size: 20),
                          SizedBox(width: 8),
                          Text('Eliminar',
                              style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
