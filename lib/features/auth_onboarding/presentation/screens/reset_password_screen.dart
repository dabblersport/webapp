import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/core/services/auth_service.dart';
import '../../../../utils/constants/route_constants.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _error;
  bool _obscure1 = true;
  bool _obscure2 = true;
  String _password = '';
  final _confirmController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'New password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure1 ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                  ),
                ),
                obscureText: _obscure1,
                onChanged: (v) => _password = v,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter a password';
                  if (v.length < 8) return 'Use at least 8 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure2 ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                  ),
                ),
                obscureText: _obscure2,
                controller: _confirmController,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Re-enter the password';
                  if (v != _password) return "Passwords don't match";
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        if (!(_formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        setState(() {
                          _isLoading = true;
                          _error = null;
                        });
                        try {
                          await AuthService().updatePassword(_password);
                          if (!mounted) return;
                          // After successful reset, go to login to sign in
                          context.go(RoutePaths.phoneInput);
                        } catch (e) {
                          setState(
                            () => _error = e.toString().replaceFirst(
                              'Exception: ',
                              '',
                            ),
                          );
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Update Password'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
