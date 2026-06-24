import '../../domain/entities/activity_history.dart';

class ActivityHistoryModel extends ActivityHistory {
  ActivityHistoryModel({
    String? id,
    String? userId,
    required DateTime activityDate,
    required int durationSeconds,
    required String primaryActivityType,
    int totalSteps = 0,
    double estimatedCalories = 0.0,
    bool fallDetected = false,
  }) : super(
          id: id,
          userId: userId,
          activityDate: activityDate,
          durationSeconds: durationSeconds,
          primaryActivityType: primaryActivityType,
          totalSteps: totalSteps,
          estimatedCalories: estimatedCalories,
          fallDetected: fallDetected,
        );

  factory ActivityHistoryModel.fromJson(Map<String, dynamic> json) {
    return ActivityHistoryModel(
      id: json['id'],
      userId: json['user_id'],
      activityDate: DateTime.parse(json['activity_date']),
      durationSeconds: json['duration_seconds'],
      primaryActivityType: json['primary_activity_type'],
      totalSteps: json['total_steps'] ?? 0,
      estimatedCalories: (json['estimated_calories'] ?? 0.0).toDouble(),
      fallDetected: json['fall_detected'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      'activity_date': activityDate.toIso8601String(),
      'duration_seconds': durationSeconds,
      'primary_activity_type': primaryActivityType,
      'total_steps': totalSteps,
      'estimated_calories': estimatedCalories,
      'fall_detected': fallDetected,
    };
  }
}
