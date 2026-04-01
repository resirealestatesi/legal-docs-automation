import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../widgets/access/code_input_field.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/error_dialog.dart';
import '../../widgets/common/premium_card.dart';
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.meshGradient,
        ),
        child: Stack(
          children: [
            // Decorative floating circle
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.05),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: PremiumCard(
                    width: 450,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: 40,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.gavel_rounded,
                            size: 40,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'LegalDocs',
                          style: AppTextStyles.headlineH1.copyWith(
                            letterSpacing: -1,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          'Automation Suite',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: AppColors.accent,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          'ACCESO CORPORATIVO',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 24),
                        CodeInputField(
                          controller: _codeController,
                          errorText: _errorText,
                          isLoading: isLoading,
                          onSubmitted: (_) => _validateCode(),
                        ),
                        const SizedBox(height: 24),
                        AppButton(
                          text: 'Ingresar',
                          onPressed: _validateCode,
                          isLoading: isLoading,
                          icon: Icons.chevron_right_rounded,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Sistema de automatización diseñado para\ngabinetes jurídicos de alto rendimiento.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
