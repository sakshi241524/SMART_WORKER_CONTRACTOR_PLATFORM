import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'job_details_worker_screen.dart';

class JobMapScreen extends StatefulWidget {
  const JobMapScreen({super.key});

  @override
  State<JobMapScreen> createState() => _JobMapScreenState();
}

class _JobMapScreenState extends State<JobMapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final Set<Marker> _markers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  Future<void> _initMap() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
        _fetchJobs();
      }
    } catch (e) {
      debugPrint("Error getting current location: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchJobs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('jobs')
          .where('status', isEqualTo: 'open')
          .get();

      final Set<Marker> newMarkers = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lat = data['latitude'] as double?;
        final lng = data['longitude'] as double?;
        final List<dynamic> rejectedBy = data['rejectedBy'] is List ? data['rejectedBy'] : [];

        if (lat != null && lng != null && !rejectedBy.contains(uid)) {
          newMarkers.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(
                title: data['workType'] ?? 'General Work',
                snippet: 'Pay: ₹${data['salary'] ?? 'N/A'}',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => JobDetailsWorkerScreen(
                        jobId: doc.id,
                        jobData: data,
                      ),
                    ),
                  );
                },
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _markers.addAll(newMarkers);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching jobs for map: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                _currentPosition?.latitude ?? 19.0760, // Fallback to Mumbai
                _currentPosition?.longitude ?? 72.8777,
              ),
              zoom: 13,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            style: Theme.of(context).brightness == Brightness.dark 
              ? _darkMapStyle // Placeholder if you had a JSON style
              : null,
          ),
          Positioned(
            top: 50,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Theme.of(context).cardColor,
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.primary),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          if (_markers.isEmpty)
            Positioned(
              bottom: 100,
              left: 50,
              right: 50,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: const Text(
                  'No available jobs found in this area.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Optional: Add a dark mode map style string here if needed
  static const String _darkMapStyle = ''; 
}
