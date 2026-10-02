import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../content/store_content.dart';
import '../theme/app_colors.dart';
import '../screens/content_screen.dart';
import 'brand_header.dart';

/// Pie de pagina de la tienda: minimalista, solo lo esencial.
///
/// Diseñado para app, no para web: una sola linea de enlaces clave,
/// copyright y ciudad. Sin version, sin columnas anchas, sin espacio
/// desperdiciado. Aparece solo en la pestana Inicio (parametro
/// `showFooter` de `ProductGrid`).
class AppFooter extends StatelessWidget {
  const AppFooter({super.key, this.onOpenCatalog});

  final VoidCallback? onOpenCatalog;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Marca compacta
          Row(
            children: [
              const BrandHeader(logoSize: 28),
              const SizedBox(width: 8),
              Text(
                'Kronio Market',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Una sola fila de enlaces esenciales (wrap en movil)
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _FooterLinkButton(
                label: 'Catalogo',
                icon: Icons.grid_view_outlined,
                onTap: onOpenCatalog,
              ),
              _FooterLinkButton(
                label: 'Contacto',
                icon: Icons.support_agent_outlined,
                onTap: () => _openContact(context),
              ),
              _FooterLinkButton(
                label: 'Privacidad',
                icon: Icons.privacy_tip_outlined,
                onTap: () => _openLegal(context, 'privacy'),
              ),
              _FooterLinkButton(
                label: 'Términos',
                icon: Icons.gavel_outlined,
                onTap: () => _openLegal(context, 'terms'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Copyright + ciudad en una linea
          Text(
            '(c) ${DateTime.now().year} Kronio Market · ${AppConfig.legalCity}',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  void _openContact(BuildContext context) async {
    final sent = await launchSupportEmail();
    if (!sent && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Escribenos a ${AppConfig.supportEmail}')),
      );
    }
  }

  void _openLegal(BuildContext context, String which) {
    final doc = which == 'privacy' ? privacyContent : termsContent;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ContentScreen(document: doc)),
    );
  }
}

/// Boton compacto de enlace para el footer minimalista.
///
/// Usa `onTap` directo en vez del enum `_FooterAction` viejo.
class _FooterLinkButton extends StatelessWidget {
  const _FooterLinkButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        highlightColor: AppColors.primary.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tope de tiempo para abrir el cliente de correo.
const Duration _emailLaunchTimeout = Duration(seconds: 5);

/// Abre el cliente de correo del usuario con el correo de soporte.
Future<bool> launchSupportEmail() async {
  final uri = Uri(
    scheme: 'mailto',
    path: AppConfig.supportEmail,
    queryParameters: const {
      'subject': 'Soporte Kronio Market',
      'body': 'Hola, necesito ayuda con: ',
    },
  );

  try {
    return await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    ).timeout(_emailLaunchTimeout, onTimeout: () => false);
  } catch (_) {
    return false;
  }
}
