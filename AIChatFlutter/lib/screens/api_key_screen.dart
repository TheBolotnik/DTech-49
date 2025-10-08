import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_state.dart';

/// Screen for API key input and management
class ApiKeyScreen extends StatefulWidget {
  const ApiKeyScreen({super.key});

  @override
  State<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends State<ApiKeyScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitKey() async {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите API ключ')),
      );
      return;
    }

    await context.read<AuthProvider>().submitApiKey(key);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ввод API ключа'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            final state = auth.state;
            final isChecking = state is AuthCheckingKey;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Введите ваш API ключ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'API ключ',
                    border: OutlineInputBorder(),
                    hintText: 'sk-...',
                  ),
                  obscureText: true,
                  enabled: !isChecking,
                ),
                const SizedBox(height: 16),
                if (state is AuthError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      state.message,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ElevatedButton(
                  onPressed: isChecking ? null : _submitKey,
                  child: isChecking
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Проверить'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
