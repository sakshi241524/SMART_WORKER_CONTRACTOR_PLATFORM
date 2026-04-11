import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class JobRankingEngine {
  /// Calculates a relevance score for a job based on worker profile and job context.
  static double calculateJobScore({
    required List<String> workerSkills,
    required Map<String, dynamic> jobRequiredProfessions,
    required dynamic createdAt,
    required dynamic jobDate,
    required bool isTargeted,
  }) {
    double skillScore = 0.0;
    double freshnessScore = 0.0;
    double urgencyScore = 0.0;
    double priorityScore = isTargeted ? 1.0 : 0.0;

    // 1. Skill Match (30% weight)
    if (workerSkills.isNotEmpty && jobRequiredProfessions.isNotEmpty) {
      bool hasMatch = false;
      for (var skill in workerSkills) {
        if (jobRequiredProfessions.keys.any((rp) => rp.toLowerCase().contains(skill.toLowerCase()))) {
          hasMatch = true;
          break;
        }
      }
      skillScore = hasMatch ? 1.0 : 0.2; // Significant boost if even one skill matches
    }

    // 2. Freshness Score (30% weight) - Decay over 24 hours
    if (createdAt != null) {
      DateTime created;
      if (createdAt is Timestamp) {
        created = createdAt.toDate();
      } else {
        created = createdAt as DateTime;
      }
      final ageMinutes = DateTime.now().difference(created).inMinutes;
      // Linear decay over 24 hours (1440 minutes)
      freshnessScore = max(0.1, 1.0 - (ageMinutes / 1440.0));
    }

    // 3. Urgency Score (30% weight) - Boost as job date approaches
    if (jobDate != null) {
      DateTime date;
      if (jobDate is Timestamp) {
        date = jobDate.toDate();
      } else {
        date = jobDate as DateTime;
      }
      final hoursUntil = date.difference(DateTime.now()).inHours;
      if (hoursUntil < 0) {
        urgencyScore = 0.0;
      } else if (hoursUntil <= 24) {
        urgencyScore = 1.0; // Very urgent
      } else if (hoursUntil <= 72) {
        urgencyScore = 0.6; // Coming up
      } else {
        urgencyScore = 0.2; // Future
      }
    }

    // Weighted Combined Score
    return (skillScore * 0.3) + (freshnessScore * 0.3) + (urgencyScore * 0.3) + (priorityScore * 0.1);
  }

  static String getRelevanceLabel(double score) {
    if (score >= 0.8) return "Best Match";
    if (score >= 0.6) return "High Relevance";
    if (score >= 0.4) return "Good Opportunity";
    return "Available";
  }
}
