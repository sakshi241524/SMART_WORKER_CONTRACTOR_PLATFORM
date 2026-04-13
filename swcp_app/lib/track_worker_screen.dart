import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class TrackWorkerScreen extends StatefulWidget {
  final String workerUid;
  final String workerName;
  final String jobId;
  final LatLng jobLocation;
  final String jobAddress;

  const TrackWorkerScreen({
    super.key,
    required this.workerUid,
    required this.workerName,
    required this.jobId,
    required this.jobLocation,
    required this.jobAddress,
  });

  @override
  State<TrackWorkerScreen> createState() => _TrackWorkerScreenState();
}

class _TrackWorkerScreenState extends State<TrackWorkerScreen> {
  GoogleMapController? _mapController;
  final Map<MarkerId, Marker> _markers = {};
  
  // To keep track of the worker's current position for auto-centering
  LatLng? _currentWorkerPos;

  @override
  void initState() {
    super.initState();
    _initMarkers();
  }

  void _initMarkers() {
    // Add Destination Marker
    _markers[const MarkerId('destination')] = Marker(
      markerId: const MarkerId('destination'),
      position: widget.jobLocation,
      infoWindow: InfoWindow(title: 'Job Site', snippet: widget.jobAddress),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );
  }

  void _updateWorkerMarker(LatLng pos) {
    setState(() {
      _markers[const MarkerId('worker')] = Marker(
        markerId: const MarkerId('worker'),
        position: pos,
        infoWindow: InfoWindow(title: widget.workerName, snippet: 'On the way'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );
      _currentWorkerPos = pos;
    });

    // Optionally auto-center map when worker moves
    // _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tracking ${widget.workerName}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3A40))),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F3A40),
        elevation: 1,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('jobs').doc(widget.jobId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final tracking = data?['tracking']?[widget.workerUid] as Map<String, dynamic>?;

          if (tracking == null || tracking['isActive'] == false) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('${widget.workerName} is no longer sharing location.', style: const TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final double lat = tracking['latitude'] ?? 0.0;
          final double lng = tracking['longitude'] ?? 0.0;
          final lastUpdate = tracking['lastUpdate'] as Timestamp?;

          final workerPos = LatLng(lat, lng);
          
          // Micro-task to update marker after build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_currentWorkerPos?.latitude != lat || _currentWorkerPos?.longitude != lng) {
              _updateWorkerMarker(workerPos);
            }
          });

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: widget.jobLocation,
                  zoom: 14,
                ),
                onMapCreated: (controller) => _mapController = controller,
                markers: Set<Marker>.of(_markers.values),
                myLocationEnabled: true,
                compassEnabled: true,
              ),
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: const Icon(Icons.directions_run, color: Colors.blue),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(widget.workerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const Text('On the way to job site', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            if (lastUpdate != null)
                              Text('Last updated: ${_formatTime(lastUpdate.toDate())}', style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          if (_mapController != null) {
                            _mapController!.animateCamera(CameraUpdate.newLatLng(workerPos));
                          }
                        },
                        icon: const Icon(Icons.my_location, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}";
  }
}
