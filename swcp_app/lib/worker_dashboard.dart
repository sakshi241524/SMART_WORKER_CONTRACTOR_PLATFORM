import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'qr_scanner_screen.dart';
import 'chat_conversation_screen.dart';
import 'worker_details_screen.dart';
import 'worker_profile_screen.dart';
import 'job_details_worker_screen.dart';
import 'role_selection_screen.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'services/job_ranking_engine.dart';
import 'package:geolocator/geolocator.dart';
import 'chats_list_screen.dart';
import 'profile_sections/ai_support_chat_screen.dart';
import 'services/translation_helper.dart';
import 'job_map_screen.dart';
import 'services/notification_service.dart';
import 'services/payment_service.dart';
import 'payment_settings_screen.dart';
import 'package:intl/intl.dart';


class WorkerDashboard extends StatefulWidget {
  final int initialIndex;
  const WorkerDashboard({super.key, this.initialIndex = 0});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  late int _selectedIndex;
  String _userName = "...";
  String? _profileImageUrl;
  List<String> _workerSkills = [];
  bool _isWorkerActive = true;
  bool _isUpdating = false;
  bool _isSharingLocation = false;
  String? _locationStatus;
  bool _isDeleteMode = false;
  final Set<String> _selectedJobIds = {};

  late Stream<QuerySnapshot> _openJobsStream;
  late Stream<QuerySnapshot> _allJobsStream;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _openJobsStream = FirebaseFirestore.instance.collection('jobs').where('status', isEqualTo: 'open').snapshots();
    _allJobsStream = FirebaseFirestore.instance.collection('jobs').snapshots();
    _loadInitialData();
    _setupNotifications();
  }

  Future<void> _setupNotifications() async {
    await NotificationService.instance.requestPermission();
    await NotificationService.instance.updateTokenInFirestore();
  }

  Future<void> _handleRefresh() async {
    await _updateCurrentLocation();
    await _refreshHeartbeat();
    setState(() {
      _openJobsStream = FirebaseFirestore.instance.collection('jobs').where('status', isEqualTo: 'open').snapshots();
      _allJobsStream = FirebaseFirestore.instance.collection('jobs').snapshots();
    });
    await _fetchUserAndStatus();
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
          _profileImageUrl = doc.data()?.containsKey('profileImageUrl') == true ? doc.get('profileImageUrl') : null;
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
      case 2: return 'Wallet';
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
    if (index != 1) {
      setState(() {
        _isDeleteMode = false;
        _selectedJobIds.clear();
      });
    }
  }

  Future<void> _rejectSelectedJobs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _selectedJobIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${_selectedJobIds.length} Jobs?'),
        content: const Text('These jobs will be removed from your list. You can\'t undo this action.'),
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
          batch.update(FirebaseFirestore.instance.collection('jobs').doc(id), {
            'rejectedBy': FieldValue.arrayUnion([uid])
          });
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Widget _buildHomeView() {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: const Color(0xFFA5555A),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                    Expanded(
                      child: Column(
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
                                Flexible(
                                  child: Text(
                                    _locationStatus ?? "Live", 
                                    style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ] else if (_locationStatus != null) ...[
                                const Icon(Icons.location_off, size: 12, color: Colors.amberAccent),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _locationStatus!, 
                                    style: const TextStyle(color: Colors.amberAccent, fontSize: 10),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
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
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
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
              stream: _openJobsStream,
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
                if (_isDeleteMode)
                  Checkbox(
                    value: _selectedJobIds.contains(jobId),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedJobIds.add(jobId);
                        } else {
                          _selectedJobIds.remove(jobId);
                        }
                      });
                    },
                    activeColor: const Color(0xFFA5555A),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['jobName'] ?? 'Untitled Job', 
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F3A40)),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1),
                      const SizedBox(height: 4),
                      Text('By: ${data['contractorName'] ?? data['constructorName'] ?? 'Contractor'}', 
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1),
                    ],
                  ),
                ),
                if (!_isDeleteMode)
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
                  if (_isDeleteMode) {
                    setState(() {
                      if (_selectedJobIds.contains(jobId)) {
                        _selectedJobIds.remove(jobId);
                      } else {
                        _selectedJobIds.add(jobId);
                      }
                    });
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => JobDetailsWorkerScreen(jobData: data, jobId: jobId),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isDeleteMode 
                      ? (_selectedJobIds.contains(jobId) ? Colors.grey : const Color(0xFFA5555A))
                      : const Color(0xFF0F3A40),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _isDeleteMode 
                    ? (_selectedJobIds.contains(jobId) ? 'Selected' : 'Select for removal') 
                    : 'View Details', 
                  style: const TextStyle(fontWeight: FontWeight.bold)
                ),
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

  Widget _buildMyJobsView() {
    return StreamBuilder<QuerySnapshot>(
      stream: _allJobsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final uid = FirebaseAuth.instance.currentUser?.uid;

        final jobScores = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final targetId = data['targetWorkerId']?.toString();
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
              'score': 1.0,
              'isJoined': true,
            };
          }
          
          if (status != 'open') return null;

          final List<dynamic> targetedIds = data['targetedWorkerIds'] is List ? data['targetedWorkerIds'] : [];
          
          bool isVisible = false;
          if (targetId != null && targetId.isNotEmpty) {
            isVisible = (targetId == uid);
          } else if (targetedIds.isNotEmpty) {
            isVisible = targetedIds.contains(uid);
          } else {
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

        jobScores.sort((a, b) {
          if (a['isJoined'] != b['isJoined']) {
            return a['isJoined'] ? -1 : 1;
          }
          return (b['score'] as double).compareTo(a['score'] as double);
        });

        if (jobScores.isEmpty) {
          return RefreshIndicator(
            onRefresh: _handleRefresh,
            color: const Color(0xFFA5555A),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 100),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.business_center_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      const Text('No jobs here yet', style: TextStyle(color: Colors.grey, fontSize: 18)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _handleRefresh,
          color: const Color(0xFFA5555A),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
          itemCount: jobScores.length,
          itemBuilder: (context, index) {
            final job = jobScores[index];
            final data = job['data'] as Map<String, dynamic>;
            final id = job['id'] as String;
            final score = job['score'] as double;

            return _buildJobCard(data, id, score);
          },
        ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> widgetOptions = <Widget>[
      _buildHomeView(),
      _buildMyJobsView(),
      _buildWalletView(),
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
          title: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _selectedIndex = 3), // Navigate to profile
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  backgroundImage: (_profileImageUrl != null && _profileImageUrl!.startsWith('data:image'))
                      ? MemoryImage(base64Decode(_profileImageUrl!.split(',').last)) as ImageProvider
                      : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                          ? CachedNetworkImageProvider(_profileImageUrl!)
                          : null,
                  child: (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                      ? Text(
                          (_userName.isNotEmpty) ? _userName[0].toUpperCase() : 'W',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hi $_userName', 
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1),
                    Text(_getAppBarTitle(context), 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).colorScheme.primary),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          elevation: 0,
          actions: [
            if (_selectedIndex == 1) // Jobs Tab
              IconButton(
                icon: const Icon(Icons.map_outlined),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const JobMapScreen())),
                color: Theme.of(context).colorScheme.primary,
                tooltip: 'Map View',
              ),
            if (_isUpdating || _locationStatus == "Updating location...")
              Center(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)),
              )),
            if (_locationStatus == "Location denied" || _locationStatus == "Location error")
              IconButton(
                icon: const Icon(Icons.location_off, color: Colors.red),
                onPressed: _updateCurrentLocation,
                tooltip: "Enable Location Access",
              ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('workerId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                  .where('isRead', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                int count = 0;
                if (snapshot.hasData) {
                  // Count total or just unread? Contractor uses isRead: false.
                  // For worker, we'll show all they haven't seen yet.
                  // For simplicity, total for now, or add isRead field logic.
                  count = snapshot.data!.docs.length;
                }

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        count > 0 ? Icons.notifications_active : Icons.notifications_none_outlined,
                        color: const Color(0xFF0F3A40),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const WorkerAlertsScreen()),
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
              },
            ),
            if (_selectedIndex == 1)
              _isDeleteMode
                ? Row(
                    children: [
                      if (_selectedJobIds.isNotEmpty)
                        TextButton(
                          onPressed: _rejectSelectedJobs,
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
          ],
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: widgetOptions,
        ),
        floatingActionButton: _selectedIndex == 1 
            ? FloatingActionButton.extended(
                heroTag: 'qr_scanner_fab',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const QRScannerScreen()),
                  );
                },
                backgroundColor: const Color(0xFF0F3A40),
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                label: const Text('Scan QR to Clock In/Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            : null,
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
              icon: const Icon(Icons.account_balance_wallet_outlined),
              activeIcon: const Icon(Icons.account_balance_wallet),
              label: 'Wallet',
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
  Widget _buildWalletView() {
    return StreamBuilder<DocumentSnapshot>(
      stream: PaymentService.instance.getWalletStream(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final double balance = (data?['walletBalance'] ?? 0.0).toDouble();
        
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Glass Balance Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F3A40), Color(0xFF1B5E68)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F3A40).withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Balance', style: TextStyle(color: Colors.white70, fontSize: 16)),
                          const SizedBox(height: 12),
                          Text(
                            '₹${balance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _showWithdrawalDialog(context, balance),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(0.2),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: const Text('Withdraw', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      'Transaction History',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F3A40),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: PaymentService.instance.getTransactionsStream(),
              builder: (context, transSnapshot) {
                if (!transSnapshot.hasData || transSnapshot.data!.docs.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          const Text('No transactions yet', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doc = transSnapshot.data!.docs[index];
                      final tData = doc.data() as Map<String, dynamic>;
                      return _buildTransactionItem(tData);
                    },
                    childCount: transSnapshot.data!.docs.length,
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }

  Future<void> _showWithdrawalDialog(BuildContext context, double balance) async {
    final details = await PaymentService.instance.getPaymentDetails();
    final TextEditingController amountController = TextEditingController();
    final upiId = details?['upiId'] ?? '';

    if (context.mounted) {
      if (upiId.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Bank Details Missing"),
            content: const Text("Please add your UPI or Bank details in Payment Settings before withdrawing."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentSettingsScreen()));
                },
                child: const Text("Add Details"),
              ),
            ],
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            bool isProcessing = false;
            String? errorText;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Column(
                children: [
                   const Icon(Icons.account_balance_wallet, size: 48, color: Color(0xFF0F3A40)),
                   const SizedBox(height: 12),
                   const Text("Withdraw Funds", style: TextStyle(fontWeight: FontWeight.bold)),
                   Text("Available: ₹${balance.toStringAsFixed(0)}", style: const TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Amount to Withdraw",
                      prefixText: "₹ ",
                      errorText: errorText,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (val) {
                      final amt = double.tryParse(val) ?? 0;
                      if (amt > balance) {
                        setDialogState(() => errorText = "Exceeds balance");
                      } else {
                        setDialogState(() => errorText = null);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Funds will be sent to UPI: $upiId",
                            style: const TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.pop(context), 
                  child: const Text("Cancel")
                ),
                ElevatedButton(
                  onPressed: (isProcessing || errorText != null) ? null : () async {
                    final amt = double.tryParse(amountController.text) ?? 0;
                    if (amt <= 0) return;

                    setDialogState(() => isProcessing = true);
                    try {
                      await PaymentService.instance.requestWithdrawal(amount: amt, upiId: upiId);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Withdrawal request sent!"), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      setDialogState(() {
                        isProcessing = false;
                        errorText = e.toString();
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F3A40),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isProcessing 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Withdraw"),
                ),
              ],
            );
          }
        ),
      );
    }
  }

  Widget _buildTransactionItem(Map<String, dynamic> data) {
    final DateTime timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final double amount = (data['amount'] ?? 0.0).toDouble();
    final String type = data['type'] ?? 'payout';
    final bool isIncome = type == 'payout';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isIncome ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIncome ? Colors.green : Colors.red,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isIncome ? 'Payment Received' : 'Withdrawal',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'} ₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: isIncome ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}

class WorkerAlertsScreen extends StatefulWidget {
  const WorkerAlertsScreen({super.key});

  @override
  State<WorkerAlertsScreen> createState() => _WorkerAlertsScreenState();
}

class _WorkerAlertsScreenState extends State<WorkerAlertsScreen> {
  bool _isDeleteMode = false;
  final Set<String> _selectedAlertIds = {};
  final Map<String, String> _selectedLanguages = {};

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
      debugPrint("Error marking worker alerts as read: $e");
    }
  }
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
                      icon: Icon(Icons.checklist, color: Theme.of(context).colorScheme.primary),
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
            final aTime = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            final bTime = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
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
                        : BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
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
                          backgroundColor: const Color(0xFF0F3A40).withOpacity(0.1),
                          child: Text(
                            (data['senderName'] != null && data['senderName'].toString().isNotEmpty) 
                                ? data['senderName'].toString()[0].toUpperCase() 
                                : (data['contractorName'] != null && data['contractorName'].toString().isNotEmpty)
                                    ? data['contractorName'].toString()[0].toUpperCase()
                                    : 'C',
                            style: const TextStyle(color: Color(0xFF0F3A40), fontWeight: FontWeight.bold),
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
                                      data['senderName'] ?? data['contractorName'] ?? 'Contractor', 
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
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
                                TranslationHelper.translate(data['message'] ?? '', _selectedLanguages[doc.id] ?? 'en'),
                                key: ValueKey('${doc.id}_${_selectedLanguages[doc.id] ?? 'en'}'),
                                style: TextStyle(
                                  color: (_selectedLanguages[doc.id] ?? 'en') != 'en' 
                                      ? Colors.blueAccent 
                                      : Theme.of(context).textTheme.bodyLarge?.color,
                                  fontStyle: (_selectedLanguages[doc.id] ?? 'en') != 'en' ? FontStyle.italic : FontStyle.normal,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
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
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                              onPressed: () async {
                                final confirm = await _showDeleteConfirm(context, "Are you sure you want to delete this notification?");
                                if (confirm == true) {
                                  await doc.reference.update({'isDeleted': true});
                                }
                              },
                              tooltip: "Delete notification",
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

