import 'package:flutter/material.dart';

import '../widgets/auth_form.dart';
import '../widgets/auth_scope.dart';
import '../widgets/google_sign_in_button.dart';

/// Pantalla de creacion de cuenta.
///
/// Manda los mismos campos que el formulario web del backend:
/// `name`, `email` y `password`.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// La confirmacion primero valida que sea una contrasena valida y recien
  /// despues que coincida, para no dar dos mensajes distintos por el mismo
  /// problema.
  String? _validateConfirm(String? value) {
    final base = validatePassword(value);
    if (base != null) return base;
    if (value != _password.text) return 'Las contrasenas no coinciden';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final auth = AuthScope.of(context);
    final ok = await auth.register(
      name: _name.text,
      email: _email.text,
      password: _password.text,
    );
    if (!mounted) return;
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final error = auth.error;

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const AuthHeader(
                icon: Icons.person_add_alt_1_outlined,
                title: 'Crea tu cuenta',
                subtitle: 'Tus pedidos y tu carrito quedan guardados',
              ),
              const SizedBox(height: 32),
              if (error != null) ...[
                AuthErrorBanner(message: error),
                const SizedBox(height: 8),
              ],
              TextFormField(
                controller: _name,
                enabled: !auth.isBusy,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: validateName,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                enabled: !auth.isBusy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Correo electronico',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: validateEmail,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                enabled: !auth.isBusy,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Contrasena',
                  prefixIcon: const Icon(Icons.lock_outline),
                  helperText: 'Minimo 6 caracteres',
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: validatePassword,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirm,
                enabled: !auth.isBusy,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Repite la contrasena',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: _validateConfirm,
              ),
              const SizedBox(height: 28),
              AuthSubmitButton(
                label: 'Crear cuenta',
                busy: auth.isBusy,
                onPressed: _submit,
              ),
              const SizedBox(height: 20),
              const AuthSeparator(),
              const SizedBox(height: 16),
              const GoogleSignInButton(),
            ],
          ),
        ),
      ),
    );
  }
}
