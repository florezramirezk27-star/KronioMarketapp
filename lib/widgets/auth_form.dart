import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Piezas y validadores compartidos por las pantallas de login y registro.

/// Valida un nombre de persona. El backend exige minimo 3 caracteres.
String? validateName(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return 'Escribe tu nombre';
  if (text.length < 3) return 'Minimo 3 caracteres';
  return null;
}

/// Valida un correo.
///
/// No pretende cubrir el RFC 5322: alcanza con descartar los errores de tipeo
/// obvios antes de gastar una peticion. La validacion de verdad la hace el
/// backend.
String? validateEmail(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return 'Escribe tu correo';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
    return 'Ese correo no parece valido';
  }
  return null;
}

/// Valida una contrasena. El backend exige minimo 6 caracteres.
String? validatePassword(String? value) {
  final text = value ?? '';
  if (text.isEmpty) return 'Escribe tu contrasena';
  if (text.length < 6) return 'Minimo 6 caracteres';
  return null;
}

/// Encabezado con icono y subtitulo para las pantallas de auth.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: scheme.primaryContainer,
          child: Icon(icon, size: 32, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Banner con el error de la ultima operacion de auth.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

/// Boton principal de las pantallas de auth.
///
/// Mientras [busy] esta en `true` queda deshabilitado y muestra un spinner, para
/// que no se puedan mandar dos veces las mismas credenciales.
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Text(label),
      ),
    );
  }
}
