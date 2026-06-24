import 'package:flutter/material.dart';
import 'package:fitness_tracker/features/history/domain/entities/activity_history.dart';
import 'package:fitness_tracker/features/history/domain/usecases/get_activity_history.dart';
import 'package:fitness_tracker/core/theme/app_theme.dart';

class DashboardPage extends StatefulWidget {
  final GetActivityHistory getActivityHistory;
  const DashboardPage({super.key, required this.getActivityHistory});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<ActivityHistory>? _records;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final records = await widget.getActivityHistory();
      if (mounted) setState(() { _records = records; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: Icon(
              themeModeNotifier.value == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () {
              themeModeNotifier.value =
                  themeModeNotifier.value == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
            },
          ),
        ],
      ),
      body: _buildBody(theme, isDark),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error al cargar datos', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _loadData, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final records = _records ?? [];
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No hay actividades registradas', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(records),
            const SizedBox(height: 20),
            _buildStatGrid(records, isDark),
            const SizedBox(height: 20),
            _buildActivityTypeDistribution(records, theme, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(List<ActivityHistory> records) {
    final total = records.length;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: const Border(top: BorderSide(color: Color(0xFF0A8BFF), width: 3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A8BFF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bar_chart, color: Color(0xFF0A8BFF), size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Resumen General', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text('$total actividades registradas', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatGrid(List<ActivityHistory> records, bool isDark) {
    final totalSteps = records.fold<int>(0, (s, r) => s + (r.totalSteps));
    final avgSteps = totalSteps / records.length;
    final totalCalories = records.fold<double>(0, (s, r) => s + r.estimatedCalories);
    final avgCalories = totalCalories / records.length;
    final totalDurationSecs = records.fold<int>(0, (s, r) => s + r.durationSeconds);
    final avgDurationSecs = totalDurationSecs / records.length;

    final bgColor = isDark ? const Color(0xFF0B1E3A) : const Color(0xFFF8FAFC);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('Estadísticas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        Row(
          children: [
            Expanded(child: _statCard('Total Pasos', _formatNumber(totalSteps), Icons.directions_walk, const Color(0xFF0A8BFF), bgColor)),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Promedio', '${_formatNumber(avgSteps.toInt())}', Icons.trending_up, const Color(0xFF12D6C8), bgColor)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statCard('Total Calorías', '${totalCalories.toStringAsFixed(0)} kcal', Icons.local_fire_department, const Color(0xFF69F06A), bgColor)),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Promedio', '${avgCalories.toStringAsFixed(0)} kcal', Icons.whatshot, Colors.orange, bgColor)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statCard('Total Duración', _formatDuration(totalDurationSecs), Icons.timer, Colors.purple, bgColor)),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Promedio', _formatDuration(avgDurationSecs.toInt()), Icons.time_to_leave, Colors.teal, bgColor)),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color iconColor, Color bgColor) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: iconColor, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 6),
                Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey))),
              ],
            ),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTypeDistribution(List<ActivityHistory> records, ThemeData theme, bool isDark) {
    final Map<String, int> typeCount = {};
    for (final r in records) {
      typeCount[r.primaryActivityType] = (typeCount[r.primaryActivityType] ?? 0) + 1;
    }
    final sorted = typeCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('Distribución por Tipo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: sorted.map((e) {
                final total = records.length;
                final pct = (e.value / total * 100).toStringAsFixed(1);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(e.key, style: const TextStyle(fontSize: 13)),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: e.value / total,
                            minHeight: 10,
                            backgroundColor: Colors.grey.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 40,
                        child: Text('${e.value}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      SizedBox(
                        width: 44,
                        child: Text('$pct%', textAlign: TextAlign.right, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}k';
    }
    return n.toString();
  }

  String _formatDuration(int seconds) {
    if (seconds >= 3600) {
      final h = seconds ~/ 3600;
      final m = (seconds % 3600) ~/ 60;
      return '${h}h ${m}m';
    }
    if (seconds >= 60) {
      return '${seconds ~/ 60}min';
    }
    return '${seconds}s';
  }
}
