import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RecommendationEngine {
  /// Calculates a match score between 0.0 and 1.0 based on multiple factors.
  static double calculateMatchScore({
    required double? contractorLat,
    required double? contractorLng,
    required double? workerLat,
    required double? workerLng,
    required List<String> workerSkills,
    required List<String> preferredSkills,
    required String workerStatus,
    required dynamic lastSeen, // Expecting Timestamp or DateTime
  }) {
    double proximityScore = 0.0;
    double skillScore = 0.0;
    double availabilityScore = 0.0;

    // 1. Proximity Score (40% weight)
    if (contractorLat != null && contractorLng != null && workerLat != null && workerLng != null) {
      double distanceInMeters = Geolocator.distanceBetween(
        contractorLat,
        contractorLng,
        workerLat,
        workerLng,
      );
      double distanceInKm = distanceInMeters / 1000;
      
      // Decay function: 1.0 at 0km, 0.0 at 10km
      proximityScore = max(0, 1.0 - (distanceInKm / 10.0));
    }

    // 2. Skill Match Score (40% weight)
    if (preferredSkills.isNotEmpty && workerSkills.isNotEmpty) {
      int matches = 0;
      for (var skill in preferredSkills) {
        if (workerSkills.any((ws) => ws.toLowerCase().contains(skill.toLowerCase()))) {
          matches++;
        }
      }
      skillScore = matches / preferredSkills.length;
    } else if (preferredSkills.isEmpty && workerSkills.isNotEmpty) {
      // If no preferences yet, give a baseline if they have skills
      skillScore = 0.5;
    }

    // 3. Predictive Availability Score (20% weight)
    if (workerStatus.toLowerCase() == 'active') {
      double livenessMultiplier = 1.0;
      
      if (lastSeen != null) {
        DateTime lastSeenDate;
        if (lastSeen is Timestamp) {
          lastSeenDate = lastSeen.toDate();
        } else if (lastSeen is DateTime) {
          lastSeenDate = lastSeen;
        } else {
          lastSeenDate = DateTime.now().subtract(const Duration(hours: 4)); // Fallback
        }

        final difference = DateTime.now().difference(lastSeenDate);
        
        if (difference.inMinutes <= 15) {
          livenessMultiplier = 1.0; // Freshly active
        } else if (difference.inMinutes <= 60) {
          livenessMultiplier = 0.8; // Still likely around
        } else if (difference.inMinutes <= 180) {
          livenessMultiplier = 0.5; // Possibly away
        } else {
          livenessMultiplier = 0.2; // Stale status
        }
      } else {
        livenessMultiplier = 0.3; // No heartbeat data
      }
      
      availabilityScore = 1.0 * livenessMultiplier;
    } else {
      availabilityScore = 0.0;
    }

    // Weighted average
    return (proximityScore * 0.4) + (skillScore * 0.4) + (availabilityScore * 0.2);
  }

  /// Helper to get a human-readable match level
  static String getMatchLevel(double score) {
    if (score >= 0.8) return "Excellent Match";
    if (score >= 0.6) return "Great Match";
    if (score >= 0.4) return "Good Match";
    return "Relevant";
  }

  /// Identifies a list of worker UIDs that match the job criteria (profession + location).
  static Future<List<String>> identifyMatchingWorkers({
    required Map<String, int> requiredWorkers,
    required String district,
    required double? contractorLat,
    required double? contractorLng,
  }) async {
    final List<String> targetIds = [];
    final professions = requiredWorkers.keys.toList();

    try {
      final workersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Worker')
          .get(); // We check status inside for more flexibility

      for (var doc in workersSnap.docs) {
        final data = doc.data();
        final workerSkills = List<String>.from(data['skills'] ?? []);
        final workerDistrict = (data['district'] ?? '').toString().toLowerCase();
        final workerStatus = data['status'] ?? 'active';
        
        if (workerStatus != 'active') continue;

        // 1. Skill Match
        bool hasSkill = professions.any((p) => 
          workerSkills.any((ws) => ws.toLowerCase().contains(p.toLowerCase()))
        );

        if (!hasSkill) continue;

        // Removed location matching as requested by user. Any active worker with a matching skill receives the job.
        targetIds.add(doc.id);
      }
    } catch (e) {
      // Use print in static context if debugPrint isn't available, but here we assume common Flutter env
      print("Error identifying matching workers: $e");
    }

    return targetIds;
  }
}
