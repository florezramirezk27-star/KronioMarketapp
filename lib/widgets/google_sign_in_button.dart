import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/auth_scope.dart';

/// Boton de "Continuar con Google".
///
/// El flujo completo:
///  1. El usuario pulsa el boton.
///  2. Se abre el navegador en `/auth/google` del backend.
///  3. El usuario se autentica con Google.
///  4. El backend redirige a `kronio://auth/google/callback?code=...`
///  5. La app recibe el deep link, intercambia el codigo por token y sesion.
///  6. El `AuthController` actualiza el estado y la UI reacciona.
///
/// Requiere que el esquema `kronio` este registrado en Android/iOS
/// (ver `android/app/src/main/AndroidManifest.xml` y `ios/Runner/Info.plist`).
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: auth.isBusy ? null : () => auth.signInWithGoogle(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              side: BorderSide(
                color: auth.isBusy
                    ? AppColors.border
                    : Theme.of(context).colorScheme.outline,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const _GoogleMark(size: 18),
            label: Text(
              auth.isBusy ? 'Conectando...' : 'Continuar con Google',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: auth.isBusy
                    ? Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.5)
                    : null,
              ),
            ),
          ),
        ),
        if (auth.error != null) ...[
          const SizedBox(height: 6),
          Text(
            auth.error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
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

/// Separador con texto, del tipo "o continua con".
///
/// Se usa en las pantallas de login y registro para separar el formulario
/// del boton de Google Sign-In.
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
