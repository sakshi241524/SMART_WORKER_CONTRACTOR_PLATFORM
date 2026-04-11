import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_conversation_screen.dart';
import 'worker_details_screen.dart';
import 'worker_profile_screen.dart';
import 'job_details_worker_screen.dart';
import 'role_selection_screen.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'services/job_ranking_engine.dart';
import 'package:geolocator/geolocator.dart';
import 'chats_list_screen.dart';

class WorkerDashboard extends StatefulWidget {
  final int initialIndex;
  const WorkerDashboard({super.key, this.initialIndex = 0});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  late int _selectedIndex;
  String _userName = "...";
  List<String> _workerSkills = [];
  bool _isWorkerActive = true;
  bool _isUpdating = false;
  bool _isSharingLocation = false;
  String? _locationStatus;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _fetchUserAndStatus();
    await _refreshHeartbeat();
    await _updateCurrentLocation();
  }

  Future<void> _refreshHeartbeat() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).update({
        'lastSeen': FieldValue.serverTimestamp(),
      }).catchError((e) => debugPrint("Heartbeat error: $e"));
    }
  }

  Future<void> _updateCurrentLocation() async {
    setState(() {
      _isSharingLocation = true;
      _locationStatus = "Updating location...";
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isSharingLocation = false;
          _locationStatus = "Location denied";
        });
        return;
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        );

        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'lastSeen': FieldValue.serverTimestamp(),
          });
          if (mounted) {
            setState(() {
              _isSharingLocation = true;
              _locationStatus = "Location active (10km)";
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error sharing location: $e");
      if (mounted) {
        setState(() {
          _isSharingLocation = false;
          _locationStatus = "Location error";
        });
      }
    }
  }

  Future<void> _fetchUserAndStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _userName = doc.get('name') ?? "Worker";
          _workerSkills = List<String>.from(doc.get('skills') ?? []);
          final status = doc.get('status') ?? 'active';
          _isWorkerActive = status == 'active';
        });
      }
    }
  }

  Future<void> _updateWorkerStatus(bool active) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isUpdating = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'status': active ? 'active' : 'inactive',
        'lastSeen': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() {
          _isWorkerActive = active;
          _isUpdating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getAppBarTitle(BuildContext context) {
    switch (_selectedIndex) {
      case 0: return 'Dashboard';
      case 1: return 'Jobs';
      case 2: return 'Alerts';
      case 3: return 'Messages';
      case 4: return 'Settings';
      default: return "Worker Dashboard";
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Persist the last active index
    Provider.of<AppState>(context, listen: false).setLastDashboardIndex(index);
  }

  Widget _buildHomeView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isWorkerActive 
                    ? [const Color(0xFF0F3A40), const Color(0xFF1B5E68)]
                    : [const Color(0xFF607D8B), const Color(0xFF455A64)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (_isWorkerActive ? const Color(0xFF0F3A40) : const Color(0xFF607D8B)).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Your Status',
                              style: TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                            const SizedBox(width: 8),
                            if (_isSharingLocation) ...[
                              const Icon(Icons.location_on, size: 12, color: Colors.greenAccent),
                              const SizedBox(width: 4),
                              Text(_locationStatus ?? "Live", style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                            ] else if (_locationStatus != null) ...[
                              const Icon(Icons.location_off, size: 12, color: Colors.amberAccent),
                              const SizedBox(width: 4),
                              Text(_locationStatus!, style: const TextStyle(color: Colors.amberAccent, fontSize: 10)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isWorkerActive ? 'ACTIVE NOW' : 'INACTIVE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isWorkerActive ? Icons.work_outline : Icons.work_off_outlined,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatusButton(
                        label: 'Active',
                        icon: Icons.check_circle_outline,
                        active: _isWorkerActive,
                        onTap: () => _updateWorkerStatus(true),
                        activeColor: const Color(0xFF00C853),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatusButton(
                        label: 'Inactive',
                        icon: Icons.pause_circle_outline,
                        active: !_isWorkerActive,
                        onTap: () => _updateWorkerStatus(false),
                        activeColor: const Color(0xFFFF5252),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          const Text(
            'Active Jobs',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F3A40),
            ),
          ),
          const SizedBox(height: 16),
          if (_isWorkerActive)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('jobs').where('status', isEqualTo: 'open').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text('Error: ${snapshot.error}');
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData) return _buildEmptyJobsView();

                final uid = FirebaseAuth.instance.currentUser?.uid;
                
                final jobScores = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final List<dynamic> rejectedBy = data['rejectedBy'] is List ? data['rejectedBy'] : [];
                  final Map<String, dynamic> accepted = data['acceptedWorkers'] is Map ? data['acceptedWorkers'] : {};
                  
                  // Check if this specific worker has rejected this job
                  if (rejectedBy.contains(uid)) return null;

                  // Check if already joined
                  bool alreadyJoined = false;
                  accepted.values.forEach((list) {
                    if (list is List && list.contains(uid)) alreadyJoined = true;
                  });
                  if (alreadyJoined) return null;
                  
                  final targetId = data['targetWorkerId'];
                  final List<dynamic> targetedIds = data['targetedWorkerIds'] is List ? data['targetedWorkerIds'] : [];
                  
                  // Targeted Dispatch Logic
                  bool isVisible = false;
                  if (targetId != null) {
                    isVisible = (targetId == uid);
                  } else if (targetedIds.isNotEmpty) {
                    isVisible = targetedIds.contains(uid);
                  } else {
                    // Legacy/Public jobs
                    isVisible = true;
                  }
                  
                  if (!isVisible) return null;

                  // Ranking Logic
                  final double score = JobRankingEngine.calculateJobScore(
                    workerSkills: _workerSkills,
                    jobRequiredProfessions: data['requiredWorkers'] ?? {},
                    createdAt: data['createdAt'],
                    jobDate: data['date'],
                    isTargeted: (targetId == uid) || targetedIds.contains(uid),
                  );

                  return {
                    'data': data,
                    'id': doc.id,
                    'score': score,
                  };
                }).whereType<Map<String, dynamic>>().toList();

                // Sort by highest relevance
                jobScores.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

                // Home view: show top 5 high-relevance jobs
                final filteredJobs = jobScores.take(10).toList();

                if (filteredJobs.isEmpty) {
                  return _buildEmptyJobsView();
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredJobs.length,
                  itemBuilder: (context, index) {
                    final job = filteredJobs[index];
                    return _buildJobCard(job['data'], job['id'], job['score']);
                  },
                );
              },
            )
          else
            _buildEmptyJobsView(),
        ],
      ),
    );
  }

  Widget _buildEmptyJobsView() {
    return Container(
      padding: const EdgeInsets.all(40),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(Icons.assignment_outlined, size: 48, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'No active jobs right now',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          if (!_isWorkerActive) ...[
            const SizedBox(height: 8),
            const Text(
              'Go active to start receiving job calls',
              style: TextStyle(color: Color(0xFFA5555A), fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> data, String jobId, [double? score]) {
    final Map<String, dynamic> required = data['requiredWorkers'] ?? {};
    final String professionSummary = required.entries.map((e) => '${e.key} ${e.value}').join(', ');
    final String label = score != null ? JobRankingEngine.getRelevanceLabel(score) : "OPEN";
    
    // Check urgency (less than 24 hours until job)
    bool isUrgent = false;
    if (data['date'] != null) {
      DateTime date = (data['date'] is Timestamp) ? (data['date'] as Timestamp).toDate() : (data['date'] as DateTime);
      if (date.difference(DateTime.now()).inHours <= 24 && date.isAfter(DateTime.now())) {
        isUrgent = true;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['jobName'] ?? 'Untitled Job', 
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F3A40))),
                      const SizedBox(height: 4),
                      Text('By: ${data['contractorName'] ?? data['constructorName'] ?? 'Contractor'}', 
                          style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isUrgent ? Colors.red.shade50 : const Color(0xFF0F3A40).withOpacity(0.1), 
                    borderRadius: BorderRadius.circular(10),
                    border: isUrgent ? Border.all(color: Colors.red.shade200) : null,
                  ),
                  child: Text(
                    isUrgent ? 'URGENT' : label.toUpperCase(), 
                    style: TextStyle(
                      color: isUrgent ? Colors.red : const Color(0xFF0F3A40), 
                      fontWeight: FontWeight.bold, 
                      fontSize: 12
                    )
                  ),
                ),
              ],
            ),
            if (score != null && score >= 0.6) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${(score * 100).toInt()}% match for your skills',
                    style: const TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Divider(),
            ),
            const Text('Required:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(professionSummary, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => JobDetailsWorkerScreen(jobData: data, jobId: jobId),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F3A40),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('View Details', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return InkWell(
      onTap: _isUpdating ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? activeColor : Colors.white24,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: active ? activeColor : Colors.white70,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: active ? activeColor : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> widgetOptions = <Widget>[
      _buildHomeView(),
      _buildMyJobsView(),
      _buildAlertsView(),
      const ChatsListScreen(),
      const WorkerProfileScreen(),
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
        backgroundColor: const Color(0xFFFBFBFC),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF0F3A40)),
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hi $_userName', style: const TextStyle(fontSize: 14, color: Colors.grey)),
              Text(_getAppBarTitle(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF0F3A40))),
            ],
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            if (_isUpdating || _locationStatus == "Updating location...")
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F3A40))),
              )),
            if (_locationStatus == "Location denied" || _locationStatus == "Location error")
              IconButton(
                icon: const Icon(Icons.location_off, color: Colors.red),
                onPressed: _updateCurrentLocation,
                tooltip: "Enable Location Access",
              ),
          ],
        ),
        body: widgetOptions.elementAt(_selectedIndex),
        bottomNavigationBar: BottomNavigationBar(
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: const Icon(Icons.dashboard_outlined),
              activeIcon: const Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.business_center_outlined),
              activeIcon: const Icon(Icons.business_center),
              label: 'Jobs',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.notifications_outlined),
              activeIcon: const Icon(Icons.notifications),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.chat_bubble_outline),
              activeIcon: const Icon(Icons.chat_bubble),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_outlined),
              activeIcon: const Icon(Icons.settings),
              label: 'Settings',
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

  Widget _buildMyJobsView() {
    return StreamBuilder<QuerySnapshot>(
      // Get all jobs (using snapshots() on collection) to handle filtering in code
      // This ensures we see joined jobs even if their status is closed
      stream: FirebaseFirestore.instance.collection('jobs').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final uid = FirebaseAuth.instance.currentUser?.uid;

        final jobScores = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final targetId = data['targetWorkerId'];
          final List<dynamic> rejectedBy = data['rejectedBy'] is List ? data['rejectedBy'] : [];
          final Map<String, dynamic> accepted = data['acceptedWorkers'] is Map ? data['acceptedWorkers'] : {};
          final String status = data['status'] ?? 'open';
          
          if (rejectedBy.contains(uid)) return null;

          bool alreadyJoined = false;
          accepted.values.forEach((list) {
            if (list is List && list.contains(uid)) alreadyJoined = true;
          });

          if (alreadyJoined) {
            return {
              'data': data,
              'id': doc.id,
              'score': 1.0, // Joined jobs at the top
              'isJoined': true,
            };
          }
          
          if (status != 'open') return null;

          final List<dynamic> targetedIds = data['targetedWorkerIds'] is List ? data['targetedWorkerIds'] : [];
          
          // Targeted Dispatch Logic
          bool isVisible = false;
          if (targetId != null) {
            isVisible = (targetId == uid);
          } else if (targetedIds.isNotEmpty) {
            isVisible = targetedIds.contains(uid);
          } else {
            // Legacy/Public jobs
            isVisible = true;
          }
          
          if (!isVisible) return null;

          final double score = JobRankingEngine.calculateJobScore(
            workerSkills: _workerSkills,
            jobRequiredProfessions: data['requiredWorkers'] ?? {},
            createdAt: data['createdAt'],
            jobDate: data['date'],
            isTargeted: (targetId == uid) || targetedIds.contains(uid),
          );

          return {
            'data': data,
            'id': doc.id,
            'score': score,
            'isJoined': false,
          };
        }).whereType<Map<String, dynamic>>().toList();

        // Sort: Joined jobs first, then by score
        jobScores.sort((a, b) {
          if (a['isJoined'] != b['isJoined']) {
            return a['isJoined'] ? -1 : 1;
          }
          return (b['score'] as double).compareTo(a['score'] as double);
        });

        if (jobScores.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.business_center_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
                const SizedBox(height: 16),
                const Text('No jobs here yet', style: TextStyle(color: Colors.grey, fontSize: 18)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: jobScores.length,
          itemBuilder: (context, index) {
            final job = jobScores[index];
            final data = job['data'] as Map<String, dynamic>;
            final id = job['id'] as String;
            final score = job['score'] as double;

            return _buildJobCard(data, id, score);
          },
        );
      },
    );
  }

  Widget _buildAlertsView() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('workerId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
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

        // Fix: Sort documents manually here to avoid needing a Firestore composite index
        final docs = snapshot.data!.docs;
        docs.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime); // Latest first
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
            final timeStr = "${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}";

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
              color: Colors.white,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF0F3A40).withOpacity(0.1),
                        child: Text(
                          data['senderName']?[0].toUpperCase() ?? data['contractorName']?[0].toUpperCase() ?? 'C',
                          style: const TextStyle(color: Color(0xFF0F3A40), fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(data['senderName'] ?? data['contractorName'] ?? 'Contractor', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(timeStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(data['message'] ?? '', style: const TextStyle(color: Colors.black87)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, right: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              final workerId = FirebaseAuth.instance.currentUser?.uid ?? '';
                              final contractorId = data['senderId'] ?? data['contractorId'] ?? '';
                              if (workerId.isEmpty || contractorId.isEmpty) return;

                              final ids = [workerId, contractorId];
                              ids.sort();
                              final chatId = ids.join('_');

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatConversationScreen(
                                    chatId: chatId,
                                    otherUserId: contractorId,
                                    otherUserName: data['senderName'] ?? data['contractorName'] ?? 'Contractor',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.reply, size: 18, color: Color(0xFF0F3A40)),
                            label: const Text('Respond', style: TextStyle(color: Color(0xFF0F3A40), fontWeight: FontWeight.bold)),
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
    );
  }
}
