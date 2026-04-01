import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../config/supabase_config.dart';
import '../../../data/datasources/remote/supabase_datasource.dart';
import '../../providers/company_provider.dart';
import '../../providers/sync_provider.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/premium_card.dart';
import '../../widgets/common/premium_header.dart';
import 'package:flutter/services.dart';

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

final totalFieldsProvider = FutureProvider.family<int, String>((ref, companyId) async {
  final supabase = Supabase.instance.client;
  
  // Get all template IDs for this company
  final templatesResp = await supabase
      .from(SupabaseConfig.templatesTable)
      .select('id')
      .eq('company_id', companyId);
      
  final templateIds = (templatesResp as List).map((t) => (t['id'] ?? '').toString()).where((id) => id.isNotEmpty).toList();
  if (templateIds.isEmpty) return 0;

  // Count all automations for those templates efficiently
  final automationsResp = await supabase
      .from(SupabaseConfig.automationsTable)
      .select('id')
      .inFilter('template_id', templateIds);
  
  return (automationsResp as List).length;
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _companyId;
  int _selectedIndex = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
      if (mounted) {
        await context.push('/highlight', extra: result.files.single);
        if (mounted && _companyId != null) {
          ref.invalidate(templatesProvider(_companyId!));
        }
      }
    }
  }


  Future<void> _editAutomation(Map<String, dynamic> t) async {
    try {
      final supabase = Supabase.instance.client;
      final datasource = SupabaseDatasource(supabase);
      final automations = await datasource.getAutomationsByTemplateId(t['id']);
      if (mounted) {
        final result = await context.push('/highlight', extra: {'template': t, 'automations': automations});
        if (result == true && _companyId != null) ref.invalidate(templatesProvider(_companyId!));
      }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _renameTemplate(Map<String, dynamic> t) async {
    final controller = TextEditingController(text: t['name']);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar Plantilla'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nuevo nombre'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Guardar')),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty && newName != t['name']) {
      try {
        final supabase = Supabase.instance.client;
        final datasource = SupabaseDatasource(supabase);
        await datasource.updateTemplate(id: t['id'], name: newName.trim());
        if (_companyId != null) ref.invalidate(templatesProvider(_companyId!));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _shareTemplate(Map<String, dynamic> t) async {
    final url = 'https://legalapp.tech/fill/${t['id']}';
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enlace de automatización copiado al portapapeles'))
      );
    }
  }

  Future<void> _deleteTemplate(Map<String, dynamic> t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Plantilla'),
        content: Text('¿Estás seguro de que deseas eliminar "${t['name']}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final supabase = Supabase.instance.client;
        final datasource = SupabaseDatasource(supabase);
        
        // Delete from storage if exists
        final fileUrl = t['file_url'] as String?;
        if (fileUrl != null && fileUrl.isNotEmpty) {
          try {
            await datasource.deleteDocxFile(fileUrl);
          } catch (_) {} // Ignore storage errors if file already gone
        }

        await datasource.deleteTemplate(t['id']);
        if (_companyId != null) ref.invalidate(templatesProvider(_companyId!));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyState = ref.watch(currentCompanyProvider);
    final company = companyState.value;

    if (company == null) return const Scaffold(body: LoadingIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      body: Row(
        children: [
          // Navigation Sidebar (Inspired by the new reference)
          _AppSidebar(
            selectedIndex: _selectedIndex,
            onIndexChanged: (i) => setState(() => _selectedIndex = i),
            onLogout: () {
              ref.read(currentCompanyProvider.notifier).logout();
              context.go('/access');
            },
          ),
          
          // Main Body
          Expanded(
            child: Column(
              children: [
                _FunctionalTopbar(
                  companyName: company.name,
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(0, 0, 24, 24),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.01),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildCurrentView(company),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentView(company) {
    switch (_selectedIndex) {
      case 0:
        return _DashboardWorkspace(
          companyName: company.name,
          onUpload: _pickDocument,
          companyId: company.id,
          onEditAutomation: _editAutomation,
          onRenameTemplate: _renameTemplate,
          onDeleteTemplate: _deleteTemplate,
          onShareTemplate: _shareTemplate,
          searchQuery: _searchQuery,
        );
      case 2:
        return _SettingsWorkspace(company: company);
      default:
        return const Center(child: Text('Sección en desarrollo'));
    }
  }
}

class _FunctionalTopbar extends StatelessWidget {
  final String companyName;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _FunctionalTopbar({required this.companyName, required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 48, 24),
      child: Row(
        children: [
          // Logo or Branding Placeholder
          const Icon(Icons.auto_awesome_mosaic_rounded, color: Color(0xFF6366F1), size: 28),
          const SizedBox(width: 16),
          Text('Dashboard', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF111827))),
          const Spacer(),
          Container(
            width: 400,
            height: 44, // Fixed height for better alignment
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Center(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Buscar por nombre...',
                  prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey),
                  prefixIconConstraints: BoxConstraints(minWidth: 32),
                  border: InputBorder.none,
                  isDense: true,
                  hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(width: 32),
          _UserAccountBadge(companyName: companyName),
        ],
      ),
    );
  }
}

class _AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onLogout;

  const _AppSidebar({
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 32),
      color: const Color(0xFF2B2D31), // Dark Slate Gray
      child: Column(
        children: [
          const Icon(Icons.gavel_rounded, color: Colors.white, size: 36),
          const SizedBox(height: 60),
          _SidebarItem(icon: Icons.grid_view_rounded, isSelected: selectedIndex == 0, onTap: () => onIndexChanged(0)),
          _SidebarItem(icon: Icons.description_outlined, isSelected: selectedIndex == 1, onTap: () => onIndexChanged(1)),
          _SidebarItem(icon: Icons.groups_outlined, isSelected: selectedIndex == 2, onTap: () => onIndexChanged(2)),
          const Spacer(),
          _SidebarItem(icon: Icons.logout_rounded, isSelected: false, onTap: onLogout, color: Colors.redAccent.shade100),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _SidebarItem({required this.icon, required this.isSelected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: InkWell(
        onTap: onTap,
        child: Icon(icon, color: color ?? (isSelected ? Colors.white : Colors.white24), size: 28),
      ),
    );
  }
}


class _UserAccountBadge extends StatelessWidget {
  final String companyName;
  const _UserAccountBadge({required this.companyName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 12, backgroundColor: AppColors.accent, child: Icon(Icons.person, size: 16, color: Colors.white)),
          const SizedBox(width: 12),
          Text(companyName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 8),
          const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16),
        ],
      ),
    );
  }
}

class _DashboardWorkspace extends StatelessWidget {
  final String companyName;
  final VoidCallback onUpload;
  final String companyId;
  final Function(Map<String, dynamic>) onEditAutomation;
  final Function(Map<String, dynamic>) onRenameTemplate;
  final Function(Map<String, dynamic>) onDeleteTemplate;
  final Function(Map<String, dynamic>) onShareTemplate;
  final String searchQuery;

  const _DashboardWorkspace({
    required this.companyName, 
    required this.onUpload, 
    required this.companyId,
    required this.onEditAutomation,
    required this.onRenameTemplate,
    required this.onDeleteTemplate,
    required this.onShareTemplate,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return ListView( // To prevent vertical overflow
      padding: EdgeInsets.zero,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Resumen General', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600)),
                Text('Visualiza y gestiona tus automatizaciones', style: AppTextStyles.bodySmall),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Dynamic Meta Cards
        Consumer(
          builder: (context, ref, child) {
            final templates = ref.watch(templatesProvider(companyId)).value ?? [];
            final fieldsCount = ref.watch(totalFieldsProvider(companyId)).value ?? 0;
            
            return Row(
              children: [
                Expanded(
                  child: _MetaCard(
                    title: 'Plantillas Listas', 
                    value: '${templates.length}', 
                    subtitle: 'Estructuras automatizadas', 
                    color: Colors.white
                  )
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _MetaCard(
                    title: 'Campos Activos', 
                    value: '$fieldsCount', 
                    subtitle: 'Variables de automatización', 
                    color: const Color(0xFF1F2937), 
                    isDark: true
                  )
                ),
              ],
            );
          }
        ),
        const SizedBox(height: 32),
        
        // Quick Action Icons
        Row(
          children: [
             _IconButtonAction(label: 'Cargar DOCX', icon: Icons.upload_file_rounded, color: const Color(0xFF6366F1), onTap: onUpload),
             const SizedBox(width: 32),
             _IconButtonAction(label: 'Importar JSON', icon: Icons.system_update_alt_rounded, color: const Color(0xFF10B981), onTap: () {}),
          ],
        ),
        
        const SizedBox(height: 48),
        Text('Plantillas Disponibles', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        
        // Detailed Table View
        _DocumentsTable(
          companyId: companyId, 
          onEdit: onEditAutomation, 
          onRename: onRenameTemplate,
          onDelete: onDeleteTemplate,
          onShare: onShareTemplate,
          searchQuery: searchQuery,
        ),
      ],
    );
  }
}

class _MetaCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final bool isDark;

  const _MetaCard({required this.title, required this.value, required this.subtitle, required this.color, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: isDark ? Colors.white70 : Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Text(value, style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade400, fontSize: 12)),
        ],
      ),
    );
  }
}

class _IconButtonAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconButtonAction({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))),
      ],
    );
  }
}

class _DocumentsTable extends ConsumerWidget {
  final String companyId;
  final Function(Map<String, dynamic>) onEdit;
  final Function(Map<String, dynamic>) onRename;
  final Function(Map<String, dynamic>) onDelete;
  final Function(Map<String, dynamic>) onShare;
  final String searchQuery;
  const _DocumentsTable({
    required this.companyId, 
    required this.onEdit, 
    required this.onRename,
    required this.onDelete,
    required this.onShare,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(templatesProvider(companyId));
    
    return templatesAsync.when(
      data: (list) {
        final filteredList = list.where((t) {
          final name = (t['name'] ?? '').toString().toLowerCase();
          return name.contains(searchQuery.toLowerCase());
        }).toList();

        if (filteredList.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No se encontraron documentos.')));
        
        return Column(
          children: [
            // Table Header
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
               child: Row(
                 children: [
                   Expanded(flex: 3, child: Text('NOMBRE', style: AppTextStyles.captionLabel)),
                   Expanded(flex: 2, child: Text('FECHA', style: AppTextStyles.captionLabel)),
                   Expanded(flex: 2, child: Text('ESTADO', style: AppTextStyles.captionLabel)),
                   Expanded(flex: 1, child: Text('OPCIONES', style: AppTextStyles.captionLabel, textAlign: TextAlign.right)),
                 ],
               ),
             ),
             const Divider(height: 1),
             
             // Table Rows
             ...filteredList.map((t) => _DocumentRow(
               template: t, 
               onEdit: () => onEdit(t),
               onRename: () => onRename(t),
               onDelete: () => onDelete(t),
               onShare: () => onShare(t),
             )),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Text('Error: $e'),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  final Map<String, dynamic> template;
  final VoidCallback onEdit;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  const _DocumentRow({
    required this.template, 
    required this.onEdit,
    required this.onRename,
    required this.onDelete,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(template['created_at'] ?? '') ?? DateTime.now();
    final formattedDate = DateFormat('MMM dd, yyyy').format(date);

    return InkWell(
      onTap: () => context.push('/fill', extra: template),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  const Icon(Icons.description_rounded, color: Color(0xFF9095A0), size: 24),
                  const SizedBox(width: 16),
                  Text(template['name'] ?? 'Innominado', style: AppTextStyles.bodySemiBold),
                ],
              ),
            ),
            Expanded(flex: 2, child: Text(formattedDate, style: AppTextStyles.bodySmall.copyWith(color: Colors.grey))),
            const Expanded(flex: 2, child: _StatusBadge(label: 'Activa', color: Colors.green)),
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerRight,
                child: _TemplateOptionMenu(
                  onConfig: onEdit,
                  onDelete: onDelete,
                  onShare: onShare,
                  onRename: onRename,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateOptionMenu extends StatelessWidget {
  final VoidCallback onConfig;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onRename;

  const _TemplateOptionMenu({
    required this.onConfig,
    required this.onDelete,
    required this.onShare,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (val) {
        if (val == 'config') onConfig();
        if (val == 'delete') onDelete();
        if (val == 'share') onShare();
        if (val == 'rename') onRename();
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: const Icon(Icons.more_horiz_rounded, color: Colors.grey, size: 20),
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'config', child: Row(children: [Icon(Icons.tune_rounded, size: 18, color: Color(0xFF4B5563)), SizedBox(width: 12), Text('Configurar Automatización')])),
        const PopupMenuItem(value: 'rename', child: Row(children: [Icon(Icons.edit_rounded, size: 18, color: Color(0xFF4B5563)), SizedBox(width: 12), Text('Renombrar')])),
        const PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.ios_share_rounded, size: 18, color: Color(0xFF4B5563)), SizedBox(width: 12), Text('Compartir')])),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red.shade400), const SizedBox(width: 12), Text('Eliminar', style: TextStyle(color: Colors.red.shade400))])),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return UnconstrainedBox(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _SettingsWorkspace extends StatelessWidget {
  final dynamic company;
  const _SettingsWorkspace({required this.company});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PremiumHeader(
          title: 'Configuración',
          subtitle: 'Gestiona los detalles de tu empresa y accesos',
          showBackButton: false,
        ),
        const SizedBox(height: 48),
        
        SizedBox(
          width: 600,
          child: Column(
            children: [
              _SettingTile(
                title: 'Nombre de la empresa',
                subtitle: company.name,
                icon: Icons.business_rounded,
                onTap: () {},
              ),
              const SizedBox(height: 16),
              _SettingTile(
                title: 'Código de Acceso',
                subtitle: company.code,
                icon: Icons.vpn_key_rounded,
                onTap: () {},
              ),
              const SizedBox(height: 16),
              _SettingTile(
                title: 'Estado de la cuenta',
                subtitle: 'Suscripción Premium Activa',
                icon: Icons.verified_user_rounded,
                color: AppColors.success,
                onTap: () {},
              ),
              const SizedBox(height: 40),
              const Divider(),
              const SizedBox(height: 24),
              Row(
                children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text('Version 1.0.4 - LegalApp Tech', style: AppTextStyles.bodySmall.copyWith(color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _SettingTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (color ?? AppColors.primary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color ?? AppColors.primary, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodySemiBold),
                Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: Colors.grey)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}
