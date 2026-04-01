import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../widgets/common/premium_card.dart';
import '../../widgets/common/premium_header.dart';

class DocumentEditorScreen extends StatelessWidget {
  const DocumentEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const PremiumHeader(
            title: 'Editor Legal',
            subtitle: 'Funcionalidad en desarrollo',
            showBackButton: true,
          ),
          Expanded(
            child: Center(
              child: PremiumCard(
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.architecture_rounded,
                      size: 64,
                      color: AppColors.accent.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Editor de Documento WYSIWYG',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Estamos construyendo un editor de alto rendimiento\npara edición final sin pérdida de formato.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Chip(
                      label: const Text('PRÓXIMAMENTE'),
                      backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                      side: BorderSide.none,
                      labelStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
