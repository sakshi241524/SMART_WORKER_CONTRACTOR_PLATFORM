import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'send_message_screen.dart';
import 'worker_profile_screen.dart';
import 'job_details_worker_screen.dart';

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({super.key});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  int _selectedIndex = 0;
  String _userName = "...";
  bool _isWorkerActive = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _fetchUserName();
    await _fetchWorkerStatus();
  }

  Future<void> _fetchUserName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _userName = doc.get('name') ?? "Worker";
        });
      }
    }
  }

  Future<void> _fetchWorkerStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() {
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

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0: return "My Dashboard";
      case 1: return "Notifications";
      case 2: return "Account Settings";
      default: return "Worker Dashboard";
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
                        const Text(
                          'Your Status',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
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
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyJobsView();
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildJobCard(data, doc.id);
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

  Widget _buildJobCard(Map<String, dynamic> data, String jobId) {
    final Map<String, dynamic> required = data['requiredWorkers'] ?? {};
    final String professionSummary = required.entries.map((e) => '${e.key} ${e.value}').join(', ');

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
                  decoration: BoxDecoration(color: const Color(0xFF0F3A40).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Text('OPEN', style: TextStyle(color: Color(0xFF0F3A40), fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
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
      _buildAlertsView(),
      const WorkerProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hi $_userName', style: const TextStyle(fontSize: 14, color: Colors.grey)),
            Text(_getAppBarTitle(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF0F3A40))),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isUpdating)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F3A40))),
            )),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF0F3A40)),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
          ),
        ],
      ),
      body: widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
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
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SendMessageScreen(
                                    recipientName: data['senderName'] ?? data['contractorName'] ?? 'Contractor',
                                    senderName: _userName,
                                    recipientId: data['senderId'] ?? data['contractorId'] ?? '',
                                    senderId: workerId,
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
