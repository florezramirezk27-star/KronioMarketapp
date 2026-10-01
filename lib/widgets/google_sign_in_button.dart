import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Boton de "Continuar con Google".
///
/// **Esta deshabilitado a proposito.** El backend no expone ningun endpoint de
/// OAuth: `POST /auth/google`, `/auth/google/signin`, `/auth/facebook` y
/// `/auth/social` responden 404 contra produccion, y `GET /auth/google` devuelve
/// un 302 que manda al frontend web, no autentica.
///
/// Poner el boton ya, aunque no haga nada, deja el sitio del boton listo y deja
/// claro el estado en vez de que falte sin explicacion. Al pulsarlo avisa por
/// snackbar en vez de fallar en silencio.
///
/// Cuando exista el endpoint hay que:
///  1. Agregar `google_sign_in` a `pubspec.yaml`.
///  2. Configurar el SHA-1 del keystore de release en la consola de Google
///     Cloud. Sin eso Google devuelve `DeveloperError` en Android.
///  3. Implementar `AuthService.signInWithGoogle` contra el endpoint real.
///  4. Cambiar `enabled` a `true` aqui y quitar el aviso.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, this.enabled = false, this.onPressed});

  /// Si es `false` el boton se ve atenuado y al pulsarlo sale un aviso de que
  /// la funcion no esta disponible todavia.
  final bool enabled;

  /// Callback cuando [enabled] es `true`.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            // No se usa `onPressed: null` de `OutlinedButton` porque dejaria
            // el boton gris plano sin explicar el porque. Sigue siendo pulsable
            // y avisa.
            onPressed: enabled ? onPressed : () => _notifyUnavailable(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              side: BorderSide(
                color: enabled
                    ? Theme.of(context).colorScheme.outline
                    : AppColors.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const _GoogleMark(size: 18),
            label: Text(
              enabled ? 'Continuar con Google' : 'Continuar con Google',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: enabled
                    ? null
                    : Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
        if (!enabled) ...[
          const SizedBox(height: 6),
          Text(
            'Disponible proximamente',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  void _notifyUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'El inicio de sesion con Google todavia no esta disponible.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
  }
}

/// La "G" multicolor de Google.
///
/// Se dibuja con `CustomPainter` en vez de una imagen para no agregar un asset
/// binario. Los cuatro trazos usan los colores oficiales de la marca.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark({this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: const _GoogleMarkPainter()),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  // Colores oficiales de la G.
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.19;

    // Cada arco es un cuarto de circunferencia. Se dibujan con `false` (solo
    // contorno) y `StrokeCap.round` para que las uniones queden redondeadas,
    // que es como se ve el logo real.
    Paint strokePaint(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    // Arco derecho (azul), de arriba hacia la derecha.
    canvas.drawArc(
      rect.deflate(stroke / 2),
      -1.5708,
      1.5708,
      false,
      strokePaint(_blue),
    );

    // Arco inferior (amarillo), de la derecha hacia abajo.
    canvas.drawArc(
      rect.deflate(stroke / 2),
      0,
      1.5708,
      false,
      strokePaint(_yellow),
    );

    // Arco izquierdo (verde), de abajo hacia la izquierda.
    canvas.drawArc(
      rect.deflate(stroke / 2),
      1.5708,
      1.5708,
      false,
      strokePaint(_green),
    );

    // Barra horizontal azul que cierra la G por la derecha.
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.5),
      Offset(size.width, size.height * 0.5),
      strokePaint(_blue),
    );

    // El tramo superior izquierdo va en rojo.
    canvas.drawArc(
      rect.deflate(stroke / 2),
      3.1416,
      0.55,
      false,
      strokePaint(_red),
    );
  }

  @override
  bool shouldRepaint(_GoogleMarkPainter oldDelegate) => false;
}

/// Separador con texto, del tipo "o continuá con".
class AuthSeparator extends StatelessWidget {
  const AuthSeparator({super.key, this.label = 'o continua con'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Divider(color: scheme.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
        Expanded(child: Divider(color: scheme.outlineVariant)),
      ],
    );
  }
}
