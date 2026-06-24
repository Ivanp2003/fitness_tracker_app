import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../data/datasources/sensors_datasource.dart';
import '../../domain/entities/activity_status.dart';
import '../../domain/usecases/monitor_activity.dart';
import '../bloc/activity_bloc.dart';
import 'fall_alert_dialog.dart';

/// Widget de Conteo de Pasos y Detector de Actividad
///
/// Modifica y reemplaza la implementación directa anterior para integrarse
/// con el ActivityBloc mediante Clean Architecture y sensors_plus.
class StepCounterWidget extends StatelessWidget {
  const StepCounterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Proveer el Bloc localmente para que sea autónomo
    return BlocProvider(
      create: (_) => ActivityBloc(
        monitorActivity: MonitorActivity(SensorsDataSourceImpl()),
        createActivityRecord: ServiceLocator.createActivityRecord,
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
      listenWhen: (previous, current) => 
          previous.errorMessage != current.errorMessage || 
          previous.saveMessage != current.saveMessage ||
          previous.status.fallState != current.status.fallState,
      listener: (context, state) {
        
        // 1. Mostrar SnackBar de guardado exitoso
        if (state.saveMessage.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Text(state.saveMessage),
                ],
              ),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // 2. Mostrar SnackBar si hay un error
        if (state.errorMessage.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage),
              backgroundColor: Colors.red.shade800,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }

        // 3. Mostrar modal si se detecta impacto inicial
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
          if (state.status.fallState == FallState.sosConfirmed) {
            return _buildSosEmergencyView(context, state);
          }
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
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Card(
      elevation: 4,
      shadowColor: const Color(0xFF0A8BFF).withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border(
            top: BorderSide(color: const Color(0xFF0A8BFF).withValues(alpha: 0.3), width: 3),
          ),
        ),
        child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A8BFF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.directions_run, color: Color(0xFF0A8BFF), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Actividad',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    if (state.isTracking) {
                      context.read<ActivityBloc>().add(StopTrackingRequested());
                    } else {
                      context.read<ActivityBloc>().add(StartTrackingRequested());
                    }
                  },
                  icon: Icon(state.isTracking ? Icons.stop : Icons.play_arrow, size: 20),
                  label: Text(state.isTracking ? 'Detener' : 'Iniciar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: state.isTracking ? Colors.red : const Color(0xFF69F06A),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: state.isTracking
                        ? Colors.red.withValues(alpha: 0.4)
                        : const Color(0xFF69F06A).withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (state.errorMessage.isEmpty)
              Container(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
            const SizedBox(height: 4),

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
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A8BFF).withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF0A8BFF).withValues(alpha: 0.08)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.directions_run, size: 56, color: const Color(0xFF0A8BFF).withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text(
                      'Presiona "Iniciar" para comenzar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Conteo de pasos y detección de caídas',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ] else ...[
              // Valor del contador
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Text(
                      '${state.status.stepCount}',
                      style: const TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A8BFF),
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'PASOS',
                      style: TextStyle(
                        fontSize: 12,
                        color: onSurface,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: Colors.grey.withValues(alpha: 0.12)),
              const SizedBox(height: 16),

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
                    color: const Color(0xFF12D6C8),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF12D6C8).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF12D6C8).withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.monitor_heart, color: const Color(0xFF12D6C8), size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'SENSORES',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Color(0xFF12D6C8),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _sensorRow('Magnitud', '${state.status.currentMagnitude.toStringAsFixed(2)} m/s²', const Color(0xFF0A8BFF)),
                    const SizedBox(height: 6),
                    _sensorRow('Promedio', '${state.status.averageMagnitude.toStringAsFixed(2)} m/s²', const Color(0xFF12D6C8)),
                    const SizedBox(height: 6),
                    _sensorRow('Cadencia', '${state.status.cadence.toStringAsFixed(1)} pasos/min', const Color(0xFF69F06A)),
                  ],
                ),
              ),
            ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_fire_department, size: 16, color: Colors.orange[400]),
                  const SizedBox(width: 6),
                    Text(
                      'Calorías: ${state.status.stepCount * 0.04} kcal',
                      style: TextStyle(color: onSurface, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sensorRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12)),
        const Spacer(),
        Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color)),
      ],
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
        return const Color(0xFF0A8BFF);
      case ActivityType.running:
        return Colors.orange;
      case ActivityType.stationary:
        return const Color(0xFF69F06A);
    }
  }
}
