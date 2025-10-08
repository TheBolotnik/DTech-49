import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_state.dart';

/// Screen for PIN code login
class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final pin = _controller.text.trim();
    if (pin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN должен содержать 4 цифры')),
      );
      return;
    }

    setState(() => _isLoading = true);
    await context.read<AuthProvider>().enterPin(pin);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сброс ключа'),
        content: const Text(
          'Вы уверены, что хотите сбросить API ключ? Вам потребуется ввести его заново.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Вход по PIN'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Введите PIN код',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'PIN',
                border: OutlineInputBorder(),
                hintText: '****',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              obscureText: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, letterSpacing: 16),
              enabled: !_isLoading,
              onSubmitted: (_) => _login(),
            ),
            const SizedBox(height: 16),
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                final state = auth.state;
                if (state is AuthError) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      state.message,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Войти'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _isLoading ? null : _reset,
              child: const Text('Сбросить ключ'),
            ),
          ],
        ),
      ),
    );
  }
}
