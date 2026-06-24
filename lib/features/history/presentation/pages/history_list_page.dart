import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/activity_history.dart';
import '../bloc/history_bloc.dart';
import '../bloc/history_event.dart';
import '../bloc/history_state.dart';

class HistoryListPage extends StatefulWidget {
  const HistoryListPage({super.key});

  @override
  State<HistoryListPage> createState() => _HistoryListPageState();
}

class _HistoryListPageState extends State<HistoryListPage> {
  @override
  void initState() {
    super.initState();
    context.read<HistoryBloc>().add(LoadHistoryEvent());
  }

  void _reauthenticateAndReload() async {
    try {
      await Supabase.instance.client.auth.signInAnonymously();
      if (mounted) {
        context.read<HistoryBloc>().add(LoadHistoryEvent());
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo restaurar la sesión')),
      );
    }
  }

  void _showEditDialog(ActivityHistory activity) {
    final stepsCtrl = TextEditingController(text: activity.totalSteps.toString());
    final calCtrl = TextEditingController(
      text: activity.estimatedCalories.toStringAsFixed(1),
    );
    String selectedType = activity.primaryActivityType;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Editar actividad'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'reposo', child: Text('Reposo')),
                    DropdownMenuItem(value: 'caminar', child: Text('Caminando')),
                    DropdownMenuItem(value: 'correr', child: Text('Corriendo')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedType = v);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: stepsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Pasos',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: calCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Calorías (kcal)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final updated = ActivityHistory(
                  id: activity.id,
                  userId: activity.userId,
                  activityDate: activity.activityDate,
                  durationSeconds: activity.durationSeconds,
                  primaryActivityType: selectedType,
                  totalSteps: int.tryParse(stepsCtrl.text) ?? activity.totalSteps,
                  estimatedCalories: double.tryParse(calCtrl.text) ?? activity.estimatedCalories,
                  fallDetected: activity.fallDetected,
                );
                context.read<HistoryBloc>().add(UpdateActivityEvent(updated));
                Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Actividad')),
      body: BlocConsumer<HistoryBloc, HistoryState>(
        listener: (context, state) {
          if (state is HistoryErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
            if (state.isAuthError) {
              _reauthenticateAndReload();
            }
          }
        },
        builder: (context, state) {
          if (state is HistoryLoadingState) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is HistoryLoadedState) {
            final items = state.history;
            if (items.isEmpty) {
              return const Center(child: Text('No hay registros de actividad.'));
            }
            return RefreshIndicator(
              onRefresh: () async {
                context.read<HistoryBloc>().add(LoadHistoryEvent());
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final activity = items[index];
                  return _ActivityCard(
                    activity: activity,
                    onEdit: () => _showEditDialog(activity),
                    onDelete: () {
                      context.read<HistoryBloc>().add(
                        DeleteActivityEvent(activity.id!),
                      );
                    },
                  );
                },
              ),
            );
          }
          return const Center(child: Text('Tira hacia abajo para recargar'));
        },
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final ActivityHistory activity;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ActivityCard({
    required this.activity,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (IconData icon, Color color, String label) = switch (activity.primaryActivityType) {
      'caminar' => (Icons.directions_walk, const Color(0xFF0A8BFF), 'Caminando'),
      'correr' => (Icons.directions_run, Colors.orange, 'Corriendo'),
      _ => (Icons.accessibility_new, const Color(0xFF69F06A), 'Reposo'),
    };

    final date = '${activity.activityDate.day.toString().padLeft(2, '0')}/'
        '${activity.activityDate.month.toString().padLeft(2, '0')}/'
        '${activity.activityDate.year}';
    final time = '${activity.activityDate.hour.toString().padLeft(2, '0')}:'
        '${activity.activityDate.minute.toString().padLeft(2, '0')}';

    final duration = activity.durationSeconds >= 60
        ? '${activity.durationSeconds ~/ 60} min ${activity.durationSeconds % 60} s'
        : '${activity.durationSeconds} s';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$date  $time',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    duration,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                _StatItem(
                  icon: Icons.directions_walk,
                  value: '${activity.totalSteps}',
                  label: 'Pasos',
                ),
                const SizedBox(width: 24),
                _StatItem(
                  icon: Icons.local_fire_department,
                  value: activity.estimatedCalories.toStringAsFixed(0),
                  label: 'kcal',
                ),
                if (activity.fallDetected) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Caída',
                          style: TextStyle(fontSize: 11, color: Colors.red[700], fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Editar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Eliminar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[400],
                    side: BorderSide(color: Colors.red[200]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
      ],
    );
  }
}
