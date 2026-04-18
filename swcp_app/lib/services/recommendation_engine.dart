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

  /// Calculates an AI matchmaking score specifically for a job's requirements
  static double calculateJobWorkerScore({
    required double? jobLat,
    required double? jobLng,
    required double? workerLat,
    required double? workerLng,
    required List<String> workerSkills,
    required List<String> requiredSkills,
    required double workerRating,
  }) {
    // 1. Proximity Score (40%)
    double proximityScore = 0.0;
    if (jobLat != null && jobLng != null && workerLat != null && workerLng != null) {
      double distKm = Geolocator.distanceBetween(jobLat, jobLng, workerLat, workerLng) / 1000.0;
      // Decay from 1.0 (at 0km) to 0.0 (at 30km)
      proximityScore = max(0.0, 1.0 - (distKm / 30.0));
    }

    // 2. Skill Score (40%)
    double skillScore = 0.0;
    if (requiredSkills.isNotEmpty && workerSkills.isNotEmpty) {
      int matches = 0;
      for (var req in requiredSkills) {
        if (workerSkills.any((ws) => ws.toLowerCase().contains(req.toLowerCase()))) {
          matches++;
        }
      }
      skillScore = matches / requiredSkills.length;
    }

    // 3. Rating Score (20%)
    double ratingScore = max(0.0, min(5.0, workerRating)) / 5.0;

    return (proximityScore * 0.4) + (skillScore * 0.4) + (ratingScore * 0.2);
  }

  /// Suggests the top N workers for a given job.
  /// Returns a list of maps: { 'worker': Map<String, dynamic>, 'score': double, 'distance': double }
  static Future<List<Map<String, dynamic>>> getTopWorkersForJob(Map<String, dynamic> jobData, {int limitCount = 3}) async {
    final double? jobLat = jobData['latitude'];
    final double? jobLng = jobData['longitude'];
    
    Map<String, dynamic> requiredWorkers = jobData['requiredWorkers'] ?? {};
    List<String> requiredSkills = requiredWorkers.keys.toList();
    if (requiredSkills.isEmpty) return [];

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Worker')
          .get();

      List<Map<String, dynamic>> scoredWorkers = [];

      for (var doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // Ensure they are active or have no status set
        if (data['status'] != null && data['status'] != 'active') continue;

        data['uid'] = doc.id;
        final workerSkills = List<String>.from(data['skills'] ?? []);
        final double? wLat = data['latitude'] ?? data['addressLat'];
        final double? wLng = data['longitude'] ?? data['addressLng'];
        final double rating = (data['rating'] != null) ? (data['rating'] as num).toDouble() : 0.0;

        double score = calculateJobWorkerScore(
          jobLat: jobLat,
          jobLng: jobLng,
          workerLat: wLat,
          workerLng: wLng,
          workerSkills: workerSkills,
          requiredSkills: requiredSkills,
          workerRating: rating,
        );

        if (score > 0.0) { // Require at least some match
          double dist = -1;
          if (jobLat != null && jobLng != null && wLat != null && wLng != null) {
            dist = Geolocator.distanceBetween(jobLat, jobLng, wLat, wLng) / 1000.0;
          }
          scoredWorkers.add({
            'worker': data,
            'score': score,
            'distance': dist,
          });
        }
      }

      scoredWorkers.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
      return scoredWorkers.take(limitCount).toList();
    } catch (e) {
      print("Error getting top workers: $e");
      return [];
    }
  }
}
