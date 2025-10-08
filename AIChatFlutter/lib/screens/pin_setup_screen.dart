import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_state.dart';

/// Screen for PIN code setup
class PinSetupScreen extends StatelessWidget {
  const PinSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройка PIN'),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final state = auth.state;
          final pin = state is AuthPinSetup ? state.pin : '';

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Ваш PIN код для входа',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue, width: 2),
                  ),
                  child: Text(
                    pin,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Запишите этот PIN код. Он потребуется для входа в приложение.',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    context.read<AuthProvider>().confirmPinSeen();
                  },
                  child: const Text('ОК, записал'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
