import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/theme/app_colors.dart';
import '../../widgets/access/code_input_field.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/error_dialog.dart';
import '../../providers/company_provider.dart';

class CompanyAccessScreen extends ConsumerStatefulWidget {
  const CompanyAccessScreen({super.key});

  @override
  ConsumerState<CompanyAccessScreen> createState() =>
      _CompanyAccessScreenState();
}

class _CompanyAccessScreenState extends ConsumerState<CompanyAccessScreen> {
  final _codeController = TextEditingController();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _checkStoredCompany();
  }

  void _checkStoredCompany() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final companyState = ref.read(currentCompanyProvider);
      companyState.whenData((company) {
        if (company != null) {
          context.go('/home');
        }
      });
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _validateCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorText = 'El código de empresa es requerido');
      return;
    }

    setState(() => _errorText = null);

    await ref.read(currentCompanyProvider.notifier).validateAndSave(code);

    final state = ref.read(currentCompanyProvider);
    state.when(
      data: (company) {
        if (company != null) {
          context.go('/home');
        }
      },
      loading: () {},
      error: (error, _) {
        ErrorDialog.show(
          context,
          message: error.toString().replaceAll('Exception: ', ''),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final companyState = ref.watch(currentCompanyProvider);
    final isLoading = companyState.isLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.description_rounded,
                    size: 40,
                    color: AppColors.onPrimary,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'LegalDocs Automation',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Legal Consulting Center',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 48),
                Text(
                  'Ingresa tu código de empresa',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                CodeInputField(
                  controller: _codeController,
                  errorText: _errorText,
                  isLoading: isLoading,
                  onSubmitted: (_) => _validateCode(),
                ),
                const SizedBox(height: 24),
                AppButton(
                  text: 'Validar y Acceder',
                  onPressed: _validateCode,
                  isLoading: isLoading,
                  icon: Icons.login_rounded,
                ),
                const SizedBox(height: 24),
                Text(
                  'El código se guardará en tu dispositivo\npara no volver a ingresarlo.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
