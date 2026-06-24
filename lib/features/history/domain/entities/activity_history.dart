class ActivityHistory {
  final String? id;
  final String? userId;
  final DateTime activityDate;
  final int durationSeconds;
  final String primaryActivityType;
  final int totalSteps;
  final double estimatedCalories;
  final bool fallDetected;

  ActivityHistory({
    this.id,
    this.userId,
    required this.activityDate,
    required this.durationSeconds,
    required this.primaryActivityType,
    this.totalSteps = 0,
    this.estimatedCalories = 0.0,
    this.fallDetected = false,
  });
}
