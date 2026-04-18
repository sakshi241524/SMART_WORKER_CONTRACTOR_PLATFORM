import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'post_job_screen.dart';
import 'worker_details_screen.dart';
import 'contractor_profile_screen.dart';
import 'direct_post_job_screen.dart';
import 'role_selection_screen.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'services/recommendation_engine.dart';
import 'data/india_data.dart';
import 'chats_list_screen.dart';
import 'profile_sections/ai_support_chat_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'chat_conversation_screen.dart';
import 'track_worker_screen.dart';
import 'services/translation_helper.dart';
import 'package:geocoding/geocoding.dart';
import 'widgets/leave_review_dialog.dart';
import 'services/notification_service.dart';

class ContractorDashboard extends StatefulWidget {
  final int initialIndex;
  const ContractorDashboard({super.key, this.initialIndex = 0});

  @override
  State<ContractorDashboard> createState() => _ContractorDashboardState();
}

class _ContractorDashboardState extends State<ContractorDashboard> {
  late int _selectedIndex;
  bool _isDeleteMode = false;
  final Set<String> _selectedJobIds = {};

  late Stream<QuerySnapshot> _workersStream;
  late Stream<QuerySnapshot> _myJobsStream;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    
    _workersStream = FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'Worker').snapshots();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _myJobsStream = FirebaseFirestore.instance.collection('jobs').where('contractorId', isEqualTo: uid).snapshots();
    } else {
      _myJobsStream = const Stream.empty();
    }
    
    _fetchUserName();
    _setupNotifications();
  }

  Future<void> _setupNotifications() async {
    await NotificationService.instance.requestPermission();
    await NotificationService.instance.updateTokenInFirestore();
  }
  String _userName = "...";
  double? _contractorLat;
  double? _contractorLng;
  List<String> _preferredSkills = [];
  bool _isFetchingLocation = false;

  String _searchQuery = "";
  String _educationFilter = "";
  bool _showOnlyShortlisted = false;
  final TextEditingController _searchController = TextEditingController();

  // Advanced Dropdown Filter State
  String? _selectedState;
  String? _selectedDistrict;
  String? _selectedProfession;

  final List<String> _professionsList = [
    'Plumber', 'Electrician', 'Carpenter', 'Mason (bricklayer)', 'Painter',
    'Welder', 'Mechanic (automobile technician)', 'AC Technician (HVAC technician)',
    'Roofer', 'Tiler (tile installer)', 'Plasterer', 'Blacksmith',
    'Construction Laborer', 'Interior Designer', 'Glass Installer (glazier)',
    'Locksmith', 'Solar Panel Installer', 'Elevator Technician',
    'Cable Technician (internet/TV wiring)'
  ];

  Future<void> _geocodeAndSaveUserAddress(String uid, Map<String, dynamic> data) async {
    try {
      final String address = data['address'] ?? '';
      final String district = data['district'] ?? '';
      final String state = data['state'] ?? '';
      if (address.isEmpty && district.isEmpty && state.isEmpty) return;
      
      final String fullAddress = "$address, $district, $state, India";
      final locations = await locationFromAddress(fullAddress);
      
      if (locations.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'addressLat': locations.first.latitude,
          'addressLng': locations.first.longitude,
        });
      }
    } catch (e) {
      debugPrint('Geocoding err for worker $uid: $e');
    }
  }

  Future<void> _fetchUserName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _userName = data['name'] ?? "Contractor";
          _contractorLat = data['latitude'] ?? data['addressLat'];
          _contractorLng = data['longitude'] ?? data['addressLng'];
        });

        if (data['latitude'] == null && data['addressLat'] == null && 
            (data['address'] != null || data['district'] != null)) {
          _geocodeAndSaveUserAddress(uid, data).then((_) async {
            if (mounted) {
              final upDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
              if (upDoc.exists && mounted && _contractorLat == null) {
                final upData = upDoc.data() as Map<String, dynamic>;
                setState(() {
                  _contractorLat = upData['latitude'] ?? upData['addressLat'];
                  _contractorLng = upData['longitude'] ?? upData['addressLng'];
                });
              }
            }
          });
        }

        if (_contractorLat == null || _contractorLng == null) {
          _fetchCurrentLocation();
        }

        _fetchPreferredSkills();
      }
    }
  }

  Future<void> _fetchCurrentLocation() async {
    if (_isFetchingLocation) return;
    setState(() => _isFetchingLocation = true);
    
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          FirebaseFirestore.instance.collection('users').doc(uid).update({
            'latitude': position.latitude,
            'longitude': position.longitude,
          }).catchError((e) => debugPrint("Error saving contractor location: $e"));
        }
        if (mounted) {
          setState(() {
            _contractorLat = position.latitude;
            _contractorLng = position.longitude;
            _isFetchingLocation = false;
          });
        }
      } else {
        if (mounted) setState(() => _isFetchingLocation = false);
      }
    } catch (e) {
      debugPrint("Error fetching dashboard location: $e");
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _handleRefresh() async {
    await _fetchCurrentLocation();
    setState(() {
      _workersStream = FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'Worker').snapshots();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        _myJobsStream = FirebaseFirestore.instance.collection('jobs').where('contractorId', isEqualTo: uid).snapshots();
      }
    });
    await _fetchUserName();
  }

  Future<void> _fetchPreferredSkills() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final jobsSnap = await FirebaseFirestore.instance
          .collection('jobs')
          .where('contractorId', isEqualTo: uid)
          .limit(10)
          .get();

      if (jobsSnap.docs.isNotEmpty) {
        Set<String> skills = {};
        for (var doc in jobsSnap.docs) {
          final data = doc.data();
          final Map<String, dynamic> required = data['requiredWorkers'] ?? {};
          skills.addAll(required.keys);
        }
        if (mounted) {
          setState(() {
            _preferredSkills = skills.toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching preferred skills: $e");
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _isDeleteMode = false;
      _selectedJobIds.clear();
    });

    Provider.of<AppState>(context, listen: false).setLastDashboardIndex(index);
  }

  Widget _buildHomeView() {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: const Color(0xFF0F3A40),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dashboard Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F3A40))),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Workers',
                  _workersStream,
                  Icons.people_outline,
                  const Color(0xFF0F3A40),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Jobs Posted',
                  _myJobsStream,
                  Icons.assignment_outlined,
                  const Color(0xFFA5555A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                const Icon(Icons.add_circle_outline, size: 48, color: Color(0xFF0F3A40)),
                const SizedBox(height: 16),
                const Text('Need specialized help?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Post a new job and reach thousands of skilled workers in your area instantly.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PostJobScreen())),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F3A40),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Post New Job', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildNearbyWorkersSection(),
        ],
      ),
      ),
    );
  }

  Widget _buildNearbyWorkersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Smart Recommendations', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F3A40)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_isFetchingLocation)
                    const Text('Updating your location...', style: TextStyle(fontSize: 10, color: Colors.blue, fontStyle: FontStyle.italic))
                  else if (_contractorLat == null)
                    InkWell(
                      onTap: _fetchCurrentLocation,
                      child: const Text('Tap to set location for better matches', style: TextStyle(fontSize: 10, color: Color(0xFFA5555A), decoration: TextDecoration.underline))
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _onItemTapped(1), 
              child: const Text('See All', style: TextStyle(color: Color(0xFFA5555A), fontWeight: FontWeight.bold))
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 220,
          child: StreamBuilder<QuerySnapshot>(
            stream: _workersStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text('Error: ${snapshot.error}');
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No workers registered yet.', style: TextStyle(color: Colors.grey)));
              }
              
              // Map, calculate scores, and filter for high-relevance matches (40%+)
              var workerScores = snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                data['uid'] = doc.id;
                
                final double rating = (data['rating'] != null) ? (data['rating'] as num).toDouble() : 0.0;
                final double? wLat = data['latitude'] ?? data['addressLat'];
                final double? wLng = data['longitude'] ?? data['addressLng'];

                // Fire and forget geocoding if both are missing but they have address info
                if (data['latitude'] == null && data['addressLat'] == null && 
                    (data['address'] != null || data['district'] != null)) {
                  _geocodeAndSaveUserAddress(doc.id, data);
                }

                final double score = RecommendationEngine.calculateMatchScore(
                  contractorLat: _contractorLat,
                  contractorLng: _contractorLng,
                  workerLat: wLat,
                  workerLng: wLng,
                  workerSkills: List<String>.from(data['skills'] ?? []),
                  preferredSkills: _preferredSkills,
                  workerStatus: data['status'] ?? 'active',
                  lastSeen: data['lastSeen'],
                );

                double distance = -1;
                if (_contractorLat != null && _contractorLng != null && wLat != null && wLng != null) {
                  distance = Geolocator.distanceBetween(
                    _contractorLat!, _contractorLng!, 
                    wLat, wLng
                  ) / 1000;
                }

                return {
                  'data': data,
                  'score': score,
                  'distance': distance,
                };
              }).where((entry) => (entry['score'] as double) >= 0.4).toList();

              // Sort by highest score
              workerScores.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

              // Take top 10
              final topWorkers = workerScores.take(10).toList();

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: topWorkers.length,
                itemBuilder: (context, index) {
                  final worker = topWorkers[index]['data'] as Map<String, dynamic>;
                  final double score = topWorkers[index]['score'] as double;
                  final double distance = topWorkers[index]['distance'] as double;
                  final String matchLevel = RecommendationEngine.getMatchLevel(score);
                  
                  // Check if worker was seen in the last 5 minutes for "Live" pulse
                  bool isLive = false;
                  if (worker['lastSeen'] != null) {
                    DateTime lastSeenDate;
                    if (worker['lastSeen'] is Timestamp) {
                      lastSeenDate = (worker['lastSeen'] as Timestamp).toDate();
                    } else {
                      lastSeenDate = worker['lastSeen'] as DateTime;
                    }
                    if (DateTime.now().difference(lastSeenDate).inMinutes <= 5 && worker['status'] == 'active') {
                      isLive = true;
                    }
                  }

                  return Container(
                    width: 170,
                    margin: const EdgeInsets.only(right: 15, bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Stack(
                      children: [
                        // Live Pulse Indicator
                        if (isLive)
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.5),
                                    blurRadius: 5,
                                    spreadRadius: 2,
                                  )
                                ],
                              ),
                            ),
                          ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: score >= 0.7 ? Colors.green.shade50 : (score >= 0.4 ? Colors.amber.shade50 : Colors.grey.shade50),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: score >= 0.7 ? Colors.green : (score >= 0.4 ? Colors.amber : Colors.grey), width: 1),
                            ),
                            child: Text(
                              '${(score * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 10, 
                                fontWeight: FontWeight.bold,
                                color: score >= 0.7 ? Colors.green : (score >= 0.4 ? Colors.amber.shade900 : Colors.grey.shade700)
                              ),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 15),
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: const Color(0xFF0F3A40).withOpacity(0.1),
                              backgroundImage: (worker['profileImageUrl'] != null && worker['profileImageUrl'].toString().startsWith('data:image'))
                                ? MemoryImage(base64Decode(worker['profileImageUrl'].toString().split(',').last)) as ImageProvider
                                : (worker['profileImageUrl'] != null && worker['profileImageUrl'].toString().isNotEmpty)
                                  ? CachedNetworkImageProvider(worker['profileImageUrl'])
                                  : null,
                              child: (worker['profileImageUrl'] == null || worker['profileImageUrl'].toString().isEmpty)
                                ? Text(
                                    (worker['name'] != null && worker['name'].toString().isNotEmpty) ? worker['name'][0].toUpperCase() : 'W',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3A40)),
                                  )
                                : null,
                            ),
                            const SizedBox(height: 8),
                            Text(worker['name'] ?? 'Worker', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(matchLevel, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (distance != -1) ...[
                                  const Icon(Icons.location_on, size: 10, color: Colors.blueGrey),
                                  Text(' ${distance.toStringAsFixed(1)}km', style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                                ] else
                                  const Text('Location unknown', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 35,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => WorkerDetailsScreen(
                                        workerData: worker,
                                        contractorName: _userName,
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F3A40),
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('View Details', style: TextStyle(fontSize: 11, color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWorkersListView() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search by name, skill, or location...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF0F3A40)),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = "");
                    })
                  : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ),

        
        if (_selectedState != null || _selectedDistrict != null || _selectedProfession != null || _educationFilter.isNotEmpty || _showOnlyShortlisted)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                   if (_showOnlyShortlisted)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Chip(
                        label: const Text('Shortlisted', style: TextStyle(fontSize: 12, color: Colors.white)),
                        backgroundColor: Colors.amber,
                        onDeleted: () => setState(() => _showOnlyShortlisted = false),
                        deleteIconColor: Colors.white,
                      ),
                    ),
                  if (_selectedState != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Chip(
                        label: Text(_selectedState!, style: const TextStyle(fontSize: 12)),
                        onDeleted: () => setState(() {
                          _selectedState = null;
                          _selectedDistrict = null;
                        }),
                      ),
                    ),
                  if (_selectedDistrict != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Chip(
                        label: Text(_selectedDistrict!, style: const TextStyle(fontSize: 12)),
                        onDeleted: () => setState(() {
                          _selectedDistrict = null;
                        }),
                      ),
                    ),
                  if (_selectedProfession != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Chip(
                        label: Text(_selectedProfession!, style: const TextStyle(fontSize: 12)),
                        onDeleted: () => setState(() => _selectedProfession = null),
                      ),
                    ),
                  if (_educationFilter.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Chip(
                        label: Text('Edu: $_educationFilter', style: const TextStyle(fontSize: 12)),
                        onDeleted: () => setState(() => _educationFilter = ""),
                      ),
                    ),
                ],
              ),
            ),
          ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _workersStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Error loading workers.', style: TextStyle(color: Colors.red)));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _handleRefresh,
                  color: const Color(0xFF0F3A40),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                       SizedBox(height: 100),
                       Center(child: Text('No workers registered yet.', style: TextStyle(color: Colors.grey))),
                    ]
                  ),
                );
              }

              // Apply Filters Client-Side
              final workers = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = (data['name'] ?? '').toString().toLowerCase();
                final address = (data['address'] ?? '').toString().toLowerCase();
                final education = (data['education'] ?? '').toString().toLowerCase();
                final workerState = (data['state'] ?? '').toString().toLowerCase();
                final workerDistrict = (data['district'] ?? '').toString().toLowerCase();
                final List<dynamic> skills = data['skills'] ?? [];
                final List<dynamic> shortlistedBy = data['shortlistedBy'] ?? [];
                
                // 1. Unified Search (Name, Skills, Address)
                bool matchesSearch = _searchQuery.isEmpty || 
                                    name.contains(_searchQuery.toLowerCase()) ||
                                    address.contains(_searchQuery.toLowerCase()) ||
                                    skills.any((s) => s.toString().toLowerCase().contains(_searchQuery.toLowerCase()));
                
                // 2. State & District Filter
                bool matchesState = _selectedState == null || workerState == _selectedState!.toLowerCase();
                bool matchesDistrict = _selectedDistrict == null || workerDistrict == _selectedDistrict!.toLowerCase();

                // 3. Profession Filter
                bool matchesProfession = _selectedProfession == null || 
                                         skills.any((s) => s.toString().toLowerCase().contains(_selectedProfession!.toLowerCase()));

                // 4. Education Filter
                bool matchesEducation = _educationFilter.isEmpty || education.contains(_educationFilter.toLowerCase());

                // 5. Shortlisted Filter
                bool matchesShortlist = !_showOnlyShortlisted || shortlistedBy.contains(uid);

                return matchesSearch && matchesState && matchesDistrict && matchesProfession && matchesEducation && matchesShortlist;
              }).toList();

              if (workers.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _handleRefresh,
                  color: const Color(0xFF0F3A40),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                       SizedBox(height: 100),
                       Center(child: Text('No workers match your filters.', style: TextStyle(color: Colors.grey))),
                    ]
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _handleRefresh,
                color: const Color(0xFF0F3A40),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                itemCount: workers.length,
                itemBuilder: (context, index) {
                  final doc = workers[index];
                  final data = doc.data() as Map<String, dynamic>;
                  data['uid'] = doc.id;
                  final List<dynamic> skills = data['skills'] ?? [];
                  final List<dynamic> shortlistedBy = data['shortlistedBy'] ?? [];
                  final bool isShortlisted = shortlistedBy.contains(uid);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFF0F3A40).withOpacity(0.1),
                                backgroundImage: (data['profileImageUrl'] != null && data['profileImageUrl'].toString().startsWith('data:image'))
                                  ? MemoryImage(base64Decode(data['profileImageUrl'].toString().split(',').last)) as ImageProvider
                                  : (data['profileImageUrl'] != null && data['profileImageUrl'].toString().isNotEmpty)
                                    ? CachedNetworkImageProvider(data['profileImageUrl'])
                                    : null,
                                child: (data['profileImageUrl'] == null || data['profileImageUrl'].toString().isEmpty)
                                  ? Text(
                                      (data['name'] != null && data['name'].toString().isNotEmpty) 
                                        ? data['name'].toString()[0].toUpperCase() 
                                        : 'W', 
                                      style: const TextStyle(color: Color(0xFF0F3A40), fontWeight: FontWeight.bold)
                                    )
                                  : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              data['name'] ?? 'Worker',
                                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F3A40)),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(Icons.star, color: Colors.amber.shade600, size: 18),
                                            Text(
                                              ' ${(data['rating'] ?? 0.0).toStringAsFixed(1)}',
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber.shade700),
                                            ),
                                          ],
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            isShortlisted ? Icons.star : Icons.star_border,
                                            color: isShortlisted ? Colors.amber : Colors.grey,
                                          ),
                                          onPressed: () => _toggleShortlist(doc.id, shortlistedBy),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: (data['status'] == 'active' || data['status'] == null) ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            (data['status'] == 'active' || data['status'] == null) ? 'ACTIVE' : 'INACTIVE',
                                            style: TextStyle(
                                              fontSize: 10, 
                                              color: (data['status'] == 'active' || data['status'] == null) ? Colors.green : Colors.grey,
                                              fontWeight: FontWeight.bold
                                            ),
                                          ),
                                        ),
                                        if (data['education'] != null && data['education'].toString().isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Icon(Icons.school, size: 12, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Text(data['education'], style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text('Skills:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: skills.map((skill) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFA5555A).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(skill.toString(), style: const TextStyle(fontSize: 12, color: Color(0xFFA5555A))),
                            )).toList(),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => WorkerDetailsScreen(
                                          workerData: data,
                                          contractorName: _userName,
                                        ),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF0F3A40)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('View Details', style: TextStyle(color: Color(0xFF0F3A40))),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context, 
                                      MaterialPageRoute(
                                        builder: (context) => DirectPostJobScreen(workerData: data)
                                      )
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F3A40),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Post Job', style: TextStyle(color: Colors.white)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, Stream<QuerySnapshot> stream, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snapshot) {
              String count = "...";
              if (snapshot.hasData) count = snapshot.data!.docs.length.toString();
              return Text(count, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildJobsListView() {
    return StreamBuilder<QuerySnapshot>(
      stream: _myJobsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return RefreshIndicator(
            onRefresh: _handleRefresh,
            color: const Color(0xFF0F3A40),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 100),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No jobs posted yet.', style: TextStyle(color: Colors.grey, fontSize: 18)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _handleRefresh,
          color: const Color(0xFF0F3A40),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
              final Map<String, dynamic> required = data['requiredWorkers'] ?? {};
              final Map<String, dynamic> accepted = data['acceptedWorkers'] ?? {};
              final String status = data['status'] ?? 'open';

              int totalRequired = 0;
              required.values.forEach((v) => totalRequired += (v as int));
              int totalAccepted = 0;
              accepted.values.forEach((v) => totalAccepted += (v as List).length);

              final bool isSelected = _selectedJobIds.contains(doc.id);

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: isSelected ? const BorderSide(color: Color(0xFFA5555A), width: 2) : BorderSide.none,
                ),
                child: Column(
                  children: [
                    if (_isDeleteMode)
                      CheckboxListTile(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedJobIds.add(doc.id);
                            } else {
                              _selectedJobIds.remove(doc.id);
                            }
                          });
                        },
                        title: Text(data['jobName'] ?? 'Untitled Job', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F3A40))),
                        subtitle: Text('Status: ${status.toUpperCase()} • $totalAccepted/$totalRequired joined'),
                        activeColor: const Color(0xFFA5555A),
                        secondary: CircleAvatar(
                          backgroundColor: status == 'open' ? const Color(0xFFA5555A).withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                          child: Icon(Icons.business_center, color: status == 'open' ? const Color(0xFFA5555A) : Colors.grey),
                        ),
                      )
                    else
                      ExpansionTile(
                        title: Text(data['jobName'] ?? 'Untitled Job', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F3A40))),
                        subtitle: Text('Status: ${status.toUpperCase()} • $totalAccepted/$totalRequired joined'),
                        leading: CircleAvatar(
                          backgroundColor: status == 'open' ? const Color(0xFFA5555A).withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                          child: Icon(Icons.business_center, color: status == 'open' ? const Color(0xFFA5555A) : Colors.grey),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildJobDetailRow('Date', DateFormat('EEE MMM dd yyyy').format(date)),
                                _buildJobDetailRow('Location', data['address'] ?? 'Not specified'),
                                const Divider(height: 24),
                                const Text('Accepted Workers by Profession:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 12),
                                ...required.entries.map((entry) {
                                  final role = entry.key;
                                  final reqCount = entry.value;
                                  final List<dynamic> joinedUids = accepted[role] ?? [];

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('$role (${joinedUids.length}/$reqCount)', style: const TextStyle(fontWeight: FontWeight.w600)),
                                        if (joinedUids.isEmpty)
                                          const Text('  No workers yet', style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic))
                                        else
                                          ...joinedUids.map((uid) => _buildWorkerNameItem(uid, doc.id, data)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                if (status == 'open') ...[
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showQrDialog(doc.id, data['jobName'] ?? 'Job'),
                                      icon: const Icon(Icons.qr_code_2),
                                      label: const Text('Show Attendance QR'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0F3A40),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () => _manualCloseJob(doc.id),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey.shade800,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Text('Close Job Manually'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _deleteSelectedJobs() async {
    if (_selectedJobIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${_selectedJobIds.length} Jobs?'),
        content: const Text('These jobs will be permanently removed. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Row(children: [CircularProgressIndicator(strokeWidth: 2), SizedBox(width: 16), Text('Deleting jobs...')]))
      );

      try {
        final batch = FirebaseFirestore.instance.batch();
        for (String id in _selectedJobIds) {
          batch.delete(FirebaseFirestore.instance.collection('jobs').doc(id));
        }
        await batch.commit();

        if (mounted) {
          setState(() {
            _isDeleteMode = false;
            _selectedJobIds.clear();
          });
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jobs deleted successfully')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting jobs: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Widget _buildWorkerNameItem(String uid, String jobId, Map<String, dynamic> jobData) {
    bool isExpanded = false;
    return StatefulBuilder(
      builder: (context, setState) {
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox(height: 20, child: LinearProgressIndicator());
            
            final workerData = snapshot.data!.data() as Map<String, dynamic>?;
            if (workerData == null) return const SizedBox();
            final name = workerData['name'] ?? 'Unknown';

            return Column(
              children: [
                InkWell(
                  onTap: () => setState(() => isExpanded = !isExpanded),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 18, color: isExpanded ? const Color(0xFFA5555A) : Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isExpanded ? FontWeight.bold : FontWeight.w500,
                                  color: isExpanded ? const Color(0xFF0F3A40) : Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.star, color: Colors.amber.shade600, size: 14),
                              Text(
                                ' ${(workerData['rating'] ?? 0.0).toStringAsFixed(1)}',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.amber.shade700),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
                if (isExpanded)
                  Container(
                    margin: const EdgeInsets.only(left: 30, bottom: 12, right: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Attendance Section
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('jobs').doc(jobId).collection('attendance').doc(uid).snapshots(),
                          builder: (context, attendanceSnap) {
                            if (!attendanceSnap.hasData || !attendanceSnap.data!.exists) {
                              return _buildDetailInfoRow(Icons.qr_code, "Attendance", "Not Arrived yet", Colors.grey);
                            }
                            
                            final attData = attendanceSnap.data!.data() as Map<String, dynamic>?;
                            final clockIn = attData?['clockIn'] as Timestamp?;
                            final clockOut = attData?['clockOut'] as Timestamp?;
                            
                            String statusText = "Clocked In: ${clockIn != null ? DateFormat('hh:mm a').format(clockIn.toDate()) : 'Pending'}";
                            if (clockOut != null) {
                              statusText += "\nClocked Out: ${DateFormat('hh:mm a').format(clockOut.toDate())}";
                            }
                            
                            return _buildDetailInfoRow(
                              clockOut != null ? Icons.fact_check : Icons.timer,
                              "Work Status",
                              statusText,
                              clockOut != null ? Colors.blueGrey : Colors.green,
                            );
                          },
                        ),
                        const Divider(height: 20),
                        
                        // Action Buttons Row
                        Row(
                          children: [
                            // Tracking Button
                            StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance.collection('jobs').doc(jobId).snapshots(),
                              builder: (context, jobSnapshot) {
                                final jData = jobSnapshot.data?.data() as Map<String, dynamic>?;
                                final tracking = jData?['tracking']?[uid] as Map<String, dynamic>?;
                                
                                if (tracking != null && tracking['isActive'] == true) {
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => TrackWorkerScreen(
                                                workerUid: uid,
                                                workerName: name,
                                                jobId: jobId,
                                                jobLocation: LatLng(jobData['latitude'] ?? 0, jobData['longitude'] ?? 0),
                                                jobAddress: jobData['address'] ?? 'Job Site',
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.location_on, size: 16),
                                        label: const Text("Track", style: TextStyle(fontSize: 12)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                            ),

                            // Rate Worker Button - Highlighted if clocked out
                            StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance.collection('jobs').doc(jobId).collection('attendance').doc(uid).snapshots(),
                              builder: (context, attendanceSnap) {
                                final attData = attendanceSnap.data?.data() as Map<String, dynamic>?;
                                final hasClockedOut = attData != null && attData['clockOut'] != null;

                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => LeaveReviewDialog(
                                            targetUserId: uid,
                                            targetUserName: name,
                                          ),
                                        );
                                      },
                                      icon: Icon(hasClockedOut ? Icons.star : Icons.star_outline, size: 16),
                                      label: const Text("Rate", style: TextStyle(fontSize: 12)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: hasClockedOut ? Colors.amber : Colors.white,
                                        foregroundColor: hasClockedOut ? Colors.white : Colors.amber.shade700,
                                        side: BorderSide(color: Colors.amber.shade300),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            
                            // Message Button
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatConversationScreen(
                                        chatId: _getChatId(FirebaseAuth.instance.currentUser!.uid, uid),
                                        otherUserId: uid,
                                        otherUserName: name,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                                label: const Text("Chat", style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0F3A40),
                                  side: const BorderSide(color: Color(0xFF0F3A40)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDetailInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(value, style: TextStyle(fontSize: 13, color: color.withOpacity(0.9), fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  String _getChatId(String id1, String id2) {
    final ids = [id1, id2];
    ids.sort();
    return ids.join('_');
  }

  void _showQrDialog(String jobId, String jobName) {
    final qrData = jsonEncode({
      "jobId": jobId,
      "type": "attendance",
      "timestamp": DateTime.now().millisecondsSinceEpoch,
    });

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Attendance QR: $jobName', style: const TextStyle(fontSize: 18, color: Color(0xFF0F3A40), fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Workers can scan this QR code to clock in and out.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 20),
              SizedBox(
                width: 200,
                height: 200,
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('jobs').doc(jobId).collection('attendance').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  final docs = snapshot.data!.docs;
                  return Text('${docs.length} workers clocked in today', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFA5555A)));
                }
              ),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            )
          ],
        );
      }
    );
  }

  Future<void> _manualCloseJob(String jobId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Job?'),
        content: const Text('This will stop workers from joining this job. You cannot undo this action.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Close Job', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({'status': 'closed'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job closed manually')));
      }
    }
  }

  Widget _buildJobDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 14),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  
  Future<void> _toggleShortlist(String workerId, List shortlistedBy) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    List updatedList = List.from(shortlistedBy);
    if (updatedList.contains(uid)) {
      updatedList.remove(uid);
    } else {
      updatedList.add(uid);
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(workerId).update({
        'shortlistedBy': updatedList,
      });
    } catch (e) {
      debugPrint("Error toggling shortlist: $e");
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final List<String> districts = _selectedState != null ? (indiaMapData[_selectedState] ?? []) : [];
          
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 32,
              top: 32,
              left: 24,
              right: 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Workers Filter', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F3A40))),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedState = null;
                            _selectedDistrict = null;
                            _selectedProfession = null;
                            _educationFilter = "";
                            _showOnlyShortlisted = false;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Reset All', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  const Text('State', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedState,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    hint: const Text('Select State'),
                    items: indiaMapData.keys.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedState = val;
                        _selectedDistrict = null;
                      });
                      setModalState(() {});
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  const Text('District', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedDistrict,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    hint: const Text('Select District'),
                    disabledHint: const Text('Select State first'),
                    items: (_selectedState != null ? (indiaMapData[_selectedState] ?? []) : [])
                        .map<DropdownMenuItem<String>>((d) => DropdownMenuItem<String>(value: d, child: Text(d))).toList(),
                    onChanged: _selectedState == null ? null : (val) {
                      setState(() {
                        _selectedDistrict = val;
                      });
                      setModalState(() {});
                    },
                  ),


                  const SizedBox(height: 20),
                  const Text('Profession', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedProfession,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    hint: const Text('Select Profession'),
                    items: _professionsList.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 14)))).toList(),
                    onChanged: (val) {
                      setState(() => _selectedProfession = val);
                      setModalState(() {});
                    },
                  ),

                  const SizedBox(height: 20),
                  const Text('Education', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (v) => setState(() => _educationFilter = v),
                    decoration: InputDecoration(
                      hintText: 'e.g., Bachelors, Diploma',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    controller: TextEditingController(text: _educationFilter),
                  ),

                  const SizedBox(height: 24),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Shortlisted Only', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3A40))),
                    subtitle: const Text('Show only starred workers'),
                    value: _showOnlyShortlisted,
                    activeColor: Colors.amber,
                    onChanged: (val) {
                      setState(() => _showOnlyShortlisted = val);
                      setModalState(() {});
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F3A40),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Apply Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileView() {
    return const ContractorProfileScreen();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetOptions = <Widget>[
      _buildHomeView(),
      _buildWorkersListView(),
      _buildJobsListView(),
      const ChatsListScreen(),
      _buildProfileView(),
    ];

    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          return false;
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
            (route) => false,
          );
          return false;
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.primary),
            onPressed: () {
              if (_selectedIndex != 0) {
                setState(() => _selectedIndex = 0);
              } else {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                  (route) => false,
                );
              }
            },
          ),
          title: Text(
            'Hi $_userName',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF0F3A40)),
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          elevation: 0,
          actions: [
            if (_selectedIndex == 1)
              IconButton(
                icon: Icon(
                  (_selectedState != null || _selectedDistrict != null || _selectedProfession != null || _educationFilter.isNotEmpty || _showOnlyShortlisted) 
                    ? Icons.filter_alt 
                    : Icons.filter_alt_outlined, 
                  color: const Color(0xFF0F3A40)
                ),
                onPressed: _showFilterSheet,
              ),
            if (_selectedIndex == 2)
              _isDeleteMode
                ? Row(
                    children: [
                      if (_selectedJobIds.isNotEmpty)
                        TextButton(
                          onPressed: _deleteSelectedJobs,
                          child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF0F3A40)),
                        onPressed: () => setState(() {
                          _isDeleteMode = false;
                          _selectedJobIds.clear();
                        }),
                      ),
                    ],
                  )
                : IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFF0F3A40)),
                    onPressed: () => setState(() => _isDeleteMode = true),
                  ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('receiverId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                  .where('isRead', isEqualTo: false)
                  .where('type', isEqualTo: 'job_accepted')
                  .snapshots(),
              builder: (context, snapshot) {
                int count = 0;
                if (snapshot.hasData) {
                  count = snapshot.data!.docs.length;
                }
                
                return Stack(
                  children: [
                    IconButton(
                      icon: Icon(
                        count > 0 ? Icons.notifications_active : Icons.notifications_none_outlined, 
                        color: const Color(0xFF0F3A40)
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ContractorAlertsScreen(contractorName: _userName)),
                        );
                      },
                    ),
                    if (count > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFA5555A),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '$count',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              }
            ),
          ],
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: widgetOptions,
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.people_outlined),
              activeIcon: const Icon(Icons.people),
              label: 'Workers',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.assignment_outlined),
              activeIcon: const Icon(Icons.assignment),
              label: 'Jobs',
            ),
            BottomNavigationBarItem(
              icon: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .where('participants', arrayContains: FirebaseAuth.instance.currentUser?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  int totalUnread = 0;
                  if (snapshot.hasData) {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final unreadCounts = data['unreadCounts'] as Map<String, dynamic>?;
                      if (unreadCounts != null && uid != null) {
                        totalUnread += (unreadCounts[uid] ?? 0) as int;
                      }
                    }
                  }

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.chat_bubble_outline),
                      if (totalUnread > 0)
                        Positioned(
                          right: -8,
                          top: -8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF25D366),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              totalUnread > 9 ? '9+' : totalUnread.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                }
              ),
              activeIcon: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .where('participants', arrayContains: FirebaseAuth.instance.currentUser?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  int totalUnread = 0;
                  if (snapshot.hasData) {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final unreadCounts = data['unreadCounts'] as Map<String, dynamic>?;
                      if (unreadCounts != null && uid != null) {
                        totalUnread += (unreadCounts[uid] ?? 0) as int;
                      }
                    }
                  }

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.chat_bubble),
                      if (totalUnread > 0)
                        Positioned(
                          right: -8,
                          top: -8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF25D366),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              totalUnread > 9 ? '9+' : totalUnread.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                }
              ),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline),
              activeIcon: const Icon(Icons.person),
              label: 'Profile',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFFA5555A),
          onTap: _onItemTapped,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
        ),
      ),
    );
  }
}

class ContractorAlertsScreen extends StatefulWidget {
  final String contractorName;
  const ContractorAlertsScreen({super.key, required this.contractorName});

  @override
  State<ContractorAlertsScreen> createState() => _ContractorAlertsScreenState();
}

class _ContractorAlertsScreenState extends State<ContractorAlertsScreen> {
  @override
  void initState() {
    super.initState();
    _markAlertsAsRead();
  }

  Future<void> _markAlertsAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snapshots = await FirebaseFirestore.instance
          .collection('notifications')
          .where('receiverId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .get();

      if (snapshots.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in snapshots.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint("Error marking contractor alerts as read: $e");
    }
  }
  bool _isDeleteMode = false;
  final Set<String> _selectedAlertIds = {};
  final Map<String, String> _selectedLanguages = {};

  String _getTranslation(String originalText, String lang) {
    return TranslationHelper.translate(originalText, lang);
  }

  Widget _buildLangOption(String alertId, String label, String langCode) {
    final bool isSelected = (_selectedLanguages[alertId] ?? 'en') == langCode;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _selectedLanguages[alertId] = langCode;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFA5555A).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFFA5555A) : Colors.grey,
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirm(BuildContext context, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllNotifications(BuildContext context, String uid) async {
    final confirm = await _showDeleteConfirm(context, "This will permanently delete ALL notifications. This action cannot be undone.");
    if (confirm != true) return;

    try {
      final snapshots = await FirebaseFirestore.instance
          .collection('notifications')
          .where('receiverId', isEqualTo: uid)
          .get();

      if (snapshots.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in snapshots.docs) {
          batch.update(doc.reference, {'isDeleted': true});
        }
        await batch.commit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All notifications cleared")));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: _isDeleteMode 
          ? IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF0F3A40)),
              onPressed: () => setState(() {
                _isDeleteMode = false;
                _selectedAlertIds.clear();
              }),
            )
          : IconButton(
              icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.primary),
              onPressed: () => Navigator.pop(context),
            ),
        actions: [
          if (!_isDeleteMode)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('receiverId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                final bool hasData = snapshot.hasData && snapshot.data!.docs.any((d) => (d.data() as Map)['isDeleted'] != true);
                return Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.checklist, color: Color(0xFF0F3A40)),
                      tooltip: "Select Messages",
                      onPressed: hasData ? () => setState(() => _isDeleteMode = true) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_sweep, color: Colors.red),
                      tooltip: "Clear All Alerts",
                      onPressed: hasData ? () => _clearAllNotifications(context, uid!) : null,
                    ),
                  ],
                );
              }
            ),
          if (_isDeleteMode)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _selectedAlertIds.isEmpty ? null : () => _deleteSelectedAlerts(context),
              tooltip: "Delete Selected",
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('receiverId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text('No alerts yet', style: TextStyle(color: Colors.grey, fontSize: 18)),
                ],
              ),
            );
          }

          final allDocs = snapshot.data!.docs;
          final docs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['isDeleted'] != true;
          }).toList();
          
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text('No alerts yet', style: TextStyle(color: Colors.grey, fontSize: 18)),
                ],
              ),
            );
          }
          
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['timestamp'] as Timestamp?;
            final bTime = bData['timestamp'] as Timestamp?;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              final timeStr = "${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}";

              return InkWell(
                onTap: _isDeleteMode 
                  ? () => setState(() {
                      if (_selectedAlertIds.contains(doc.id)) {
                        _selectedAlertIds.remove(doc.id);
                      } else {
                        _selectedAlertIds.add(doc.id);
                      }
                    })
                  : null,
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: _isDeleteMode && _selectedAlertIds.contains(doc.id)
                        ? const BorderSide(color: Colors.red, width: 2)
                        : BorderSide(color: Colors.grey.shade100),
                  ),
                  elevation: 0,
                  color: _isDeleteMode && _selectedAlertIds.contains(doc.id)
                      ? Colors.red.withOpacity(0.05)
                      : Theme.of(context).cardColor,
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: _isDeleteMode
                          ? Checkbox(
                              value: _selectedAlertIds.contains(doc.id),
                              onChanged: (val) => setState(() {
                                if (val == true) {
                                  _selectedAlertIds.add(doc.id);
                                } else {
                                  _selectedAlertIds.remove(doc.id);
                                }
                              }),
                              activeColor: Colors.red,
                            )
                          : CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          child: Text(
                            (data['senderName'] != null && data['senderName'].toString().isNotEmpty) 
                                ? data['senderName'].toString()[0].toUpperCase() 
                                : 'W',
                            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      data['senderName'] ?? 'Worker',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (data['isRead'] == false)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(timeStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                _getTranslation(data['message'] ?? '', _selectedLanguages[doc.id] ?? 'en'),
                                key: ValueKey('${doc.id}_${_selectedLanguages[doc.id] ?? 'en'}'),
                                style: TextStyle(
                                  color: (_selectedLanguages[doc.id] ?? 'en') != 'en' ? Colors.blueAccent : Colors.black87,
                                  fontStyle: (_selectedLanguages[doc.id] ?? 'en') != 'en' ? FontStyle.italic : FontStyle.normal,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.translate, size: 10, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    _buildLangOption(doc.id, 'En', 'en'),
                                    const Text(" | ", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    _buildLangOption(doc.id, 'Hi', 'hi'),
                                    const Text(" | ", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    _buildLangOption(doc.id, 'Mr', 'mr'),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                                  onPressed: () async {
                                    final confirm = await _showDeleteConfirm(context, "Are you sure you want to delete this notification?");
                                    if (confirm == true) {
                                      await doc.reference.update({'isDeleted': true});
                                    }
                                  },
                                  tooltip: "Delete notification",
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, right: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                final contractorId = FirebaseAuth.instance.currentUser?.uid ?? '';
                                final workerId = data['senderId'] ?? '';
                                if (contractorId.isEmpty || workerId.isEmpty) return;

                                final ids = [contractorId, workerId];
                                ids.sort();
                                final chatId = ids.join('_');

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatConversationScreen(
                                      chatId: chatId,
                                      otherUserId: workerId,
                                      otherUserName: data['senderName'] ?? 'Worker',
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(Icons.reply, size: 18, color: Theme.of(context).colorScheme.primary),
                              label: Text('Respond', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
  Future<void> _deleteSelectedAlerts(BuildContext context) async {
    final confirm = await _showDeleteConfirm(context, "Are you sure you want to delete ${_selectedAlertIds.length} selected notifications?");
    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (String id in _selectedAlertIds) {
        batch.update(FirebaseFirestore.instance.collection('notifications').doc(id), {'isDeleted': true});
      }
      await batch.commit();
      
      if (mounted) {
        setState(() {
          _isDeleteMode = false;
          _selectedAlertIds.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selected notifications deleted")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }
}


