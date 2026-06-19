import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/sensors_datasource.dart';
import '../../domain/entities/activity_status.dart';
import '../../domain/usecases/monitor_activity.dart';
import '../bloc/activity_bloc.dart';
import 'fall_alert_dialog.dart';

/// Widget de Conteo de Pasos y Detector de Actividad
///
/// Modifica y reemplaza la implementación directa anterior para integrarse
/// con el ActivityBloc mediante Clean Architecture y sensores_plus.
class StepCounterWidget extends StatelessWidget {
  const StepCounterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Proveer el Bloc localmente para que sea autónomo
    return BlocProvider(
      create: (_) => ActivityBloc(
        MonitorActivity(SensorsDataSourceImpl()),
      ),
      child: const StepCounterView(),
    );
  }
}

class StepCounterView extends StatefulWidget {
  const StepCounterView({super.key});

  @override
  State<StepCounterView> createState() => _StepCounterViewState();
}

class _StepCounterViewState extends State<StepCounterView> {
  bool _isDialogOpen = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ActivityBloc, ActivityState>(
      listener: (context, state) {
        // Mostrar modal si se detecta impacto inicial
        if (state.status.fallState == FallState.impactDetected) {
          if (!_isDialogOpen) {
            _isDialogOpen = true;
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) => BlocProvider.value(
                value: context.read<ActivityBloc>(),
                child: const FallAlertDialog(),
              ),
            ).then((_) {
              _isDialogOpen = false;
            });
          }
        } else {
          // Si el estado cambia (normal o SOS confirmado), cerramos el diálogo
          if (_isDialogOpen) {
            Navigator.of(context, rootNavigator: true).pop();
            _isDialogOpen = false;
          }
        }
      },
      child: BlocBuilder<ActivityBloc, ActivityState>(
        builder: (context, state) {
          // Si se confirma el SOS, renderizamos la pantalla de emergencia roja
          if (state.status.fallState == FallState.sosConfirmed) {
            return _buildSosEmergencyView(context, state);
          }

          // Si no, mostramos la UI principal de seguimiento
          return _buildStepTrackerCard(context, state);
        },
      ),
    );
  }

  /// Vista de Emergencia SOS Activa (Pantalla Completa / Panel Rojo Pulsante)
  Widget _buildSosEmergencyView(BuildContext context, ActivityState state) {
    return Card(
      color: Colors.red[900],
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.contact_phone_rounded,
              size: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            const Text(
              '¡ALERTA SOS ACTIVA!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Se ha detectado una caída y el usuario no responde. El dispositivo está emitiendo una alerta por voz de forma continua.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 24),
            // Botón de Cancelación Manual solicitado
            ElevatedButton.icon(
              onPressed: () {
                context.read<ActivityBloc>().add(ResetEmergencyRequested());
              },
              icon: const Icon(Icons.cancel_outlined, size: 24),
              label: const Text('CANCELAR ALERTA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red[900],
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tarjeta principal de conteo y monitoreo físico
  Widget _buildStepTrackerCard(BuildContext context, ActivityState state) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Cabecera del control de tracking
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Actividad y Movimiento',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    if (state.isTracking) {
                      context.read<ActivityBloc>().add(StopTrackingRequested());
                    } else {
                      context.read<ActivityBloc>().add(StartTrackingRequested());
                    }
                  },
                  icon: Icon(state.isTracking ? Icons.stop : Icons.play_arrow),
                  label: Text(state.isTracking ? 'Detener' : 'Iniciar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: state.isTracking ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            if (state.errorMessage.isNotEmpty) ...[
              Text(
                state.errorMessage,
                style: const TextStyle(color: Colors.red, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],

            if (!state.isTracking) ...[
              const SizedBox(height: 20),
              Icon(Icons.directions_run, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'Presiona "Iniciar" para comenzar el conteo de pasos y la detección inteligente de caídas.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 20),
            ] else ...[
              // Valor del contador
              Text(
                '${state.status.stepCount}',
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6366F1),
                ),
              ),
              const Text(
                'PASOS REGISTRADOS',
                style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // Fila de información adicional
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatusChip(
                    icon: _getActivityIcon(state.status.activityType),
                    label: _getActivityLabel(state.status.activityType),
                    color: _getActivityColor(state.status.activityType),
                  ),
                  _buildStatusChip(
                    icon: Icons.graphic_eq_rounded,
                    label: '${state.status.currentMagnitude.toStringAsFixed(2)} m/s²',
                    color: Colors.purple,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.build_circle, color: Colors.amber.shade800, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'PANEL DE CALIBRACIÓN',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.amber.shade800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16, thickness: 1),
                    Text(
                      '• Magnitud cruda: ${state.status.currentMagnitude.toStringAsFixed(4)} m/s²',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Promedio móvil (avg): ${state.status.averageMagnitude.toStringAsFixed(4)} m/s²',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Actividad detectada: ${state.status.activityType.name.toUpperCase()}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.deepOrange,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Cadencia actual: ${state.status.cadence.toStringAsFixed(1)} pasos/min',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Calorías Estimadas: ${state.status.stepCount * 0.04} kcal',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.walking:
        return Icons.directions_walk;
      case ActivityType.running:
        return Icons.directions_run;
      case ActivityType.stationary:
        return Icons.accessibility_new;
    }
  }

  String _getActivityLabel(ActivityType type) {
    switch (type) {
      case ActivityType.walking:
        return 'Caminando';
      case ActivityType.running:
        return 'Corriendo';
      case ActivityType.stationary:
        return 'En Reposo';
    }
  }

  Color _getActivityColor(ActivityType type) {
    switch (type) {
      case ActivityType.walking:
        return Colors.blue;
      case ActivityType.running:
        return Colors.orange;
      case ActivityType.stationary:
        return Colors.green;
    }
  }
}
