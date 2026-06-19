import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/activity_bloc.dart';

/// Diálogo de Emergencia por Caída
///
/// Muestra una cuenta regresiva visual vinculada al estado del Bloc
/// y permite cancelar la alerta si el usuario se encuentra bien.
class FallAlertDialog extends StatelessWidget {
  const FallAlertDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActivityBloc, ActivityState>(
      builder: (context, state) {
        final countdown = state.countdown;

        return PopScope(
          canPop: false, // Impedir cerrar pulsando fuera o el botón atrás de Android
          child: AlertDialog(
            backgroundColor: Colors.red[50],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Colors.red, width: 2),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
                SizedBox(width: 10),
                Text(
                  '¡Impacto Detectado!',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Hemos registrado un movimiento brusco compatible con una caída.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                const Text(
                  '¿Se encuentra bien?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 80,
                      width: 80,
                      child: CircularProgressIndicator(
                        value: countdown / 15,
                        strokeWidth: 6,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                        backgroundColor: Colors.red.withValues(alpha: 0.1),
                      ),
                    ),
                    Text(
                      '$countdown',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Si no responde, se activará la alerta SOS de voz.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton.icon(
                onPressed: () {
                  context.read<ActivityBloc>().add(ResetEmergencyRequested());
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('ESTOY BIEN'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  elevation: 2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
