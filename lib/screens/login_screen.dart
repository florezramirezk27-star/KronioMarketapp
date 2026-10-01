import 'package:flutter/material.dart';

import '../widgets/auth_form.dart';
import '../widgets/auth_scope.dart';
import '../widgets/google_sign_in_button.dart';

/// Pantalla de inicio de sesion.
///
/// El backend autentica con cookie httpOnly (no bearer), asi que no hay token
/// que guardar en la pantalla: el [AuthController] y el cookie jar se encargan.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final auth = AuthScope.of(context);
    final ok = await auth.login(email: _email.text, password: _password.text);
    if (!mounted) return;
    if (ok) Navigator.of(context).pop(true);
  }

  Future<void> _openRegister() async {
    final auth = AuthScope.of(context);
    auth.clearError();
    final created = await Navigator.of(context).pushNamed<bool>('/register');
    if (!mounted) return;
    // Si el registro ya dejo la sesion iniciada, se cierra tambien el login
    // para volver directo a "Mi cuenta".
    if (created == true) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final error = auth.error;

    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesion')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const AuthHeader(
                icon: Icons.lock_outline,
                title: 'Bienvenido de vuelta',
                subtitle: 'Entra para ver tus pedidos y comprar mas rapido',
              ),
              const SizedBox(height: 32),
              if (error != null) ...[
                AuthErrorBanner(message: error),
                const SizedBox(height: 8),
              ],
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
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Contrasena',
                  prefixIcon: const Icon(Icons.lock_outline),
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
              const SizedBox(height: 28),
              AuthSubmitButton(
                label: 'Entrar',
                busy: auth.isBusy,
                onPressed: _submit,
              ),
              const SizedBox(height: 20),
              const AuthSeparator(),
              const SizedBox(height: 16),
              const GoogleSignInButton(),
              const SizedBox(height: 8),
              TextButton(
                onPressed: auth.isBusy ? null : _openRegister,
                child: const Text('No tengo cuenta, quiero registrarme'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
