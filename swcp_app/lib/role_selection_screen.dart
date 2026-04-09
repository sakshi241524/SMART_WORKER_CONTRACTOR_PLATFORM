import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'signin_screen.dart';
import 'welcome_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'contractor_dashboard.dart';
import 'worker_dashboard.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Record this as the last visited guest route
    // Note: We're keeping this for state persistence if AuthWrapper needs a fallback,
    // although the app now always starts at Welcome.
    Future.microtask(() {
      Provider.of<AppState>(context, listen: false).setLastGuestRoute('RoleSelection');
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF3E5D8), // Light beige background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: TextButton.icon(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              // If we arrived here via a 'pushAndRemoveUntil' (like from Dashboards),
              // we need to explicitly navigate back to the Welcome screen.
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                (route) => false,
              );
            }
          },
          icon: const Icon(Icons.arrow_back, color: Colors.black54, size: 20),
          label: const Text(
            'Back',
            style: TextStyle(color: Colors.black54, fontSize: 16),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
          ),
        ),
        leadingWidth: 100,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Choose the Role',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F3A40), // Dark teal/green
                ),
              ),
              const SizedBox(height: 50),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildRoleCard(
                    context,
                    title: 'CONTRACTOR',
                    icon: Icons.engineering,
                    onPressed: () => _handleRoleSelection(context, 'Contractor'),
                  ),
                  _buildRoleCard(
                    context,
                    title: 'WORKER',
                    icon: Icons.handyman,
                    onPressed: () => _handleRoleSelection(context, 'Worker'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleRoleSelection(BuildContext context, String selectedRole) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // User is logged in, check if their stored role matches the selection
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          String? storedRole = userDoc.get('role');
          if (storedRole == selectedRole) {
            // Perfect match! Go to dashboard
            appState.dismissWelcome();
            if (context.mounted) {
              Widget dashboard = selectedRole == 'Contractor' 
                  ? ContractorDashboard() 
                  : WorkerDashboard();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => dashboard),
                (route) => false,
              );
            }
            return;
          } else {
            // Roles don't match. 
            // The user wants to switch from one specific account to another.
            // We'll sign out the current user automatically to allow the switch.
            await FirebaseAuth.instance.signOut();
            appState.clearPersistence();
            // Fall through to the sign-in screen below
          }
        }
      } catch (e) {
        debugPrint("Error checking role: $e");
        await FirebaseAuth.instance.signOut();
      }
    }

    // If not logged in (or just signed out due to mismatch), go to sign in screen
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SignInScreen(role: selectedRole),
        ),
      );
    }
  }

  Widget _buildRoleCard(BuildContext context, {required String title, required IconData icon, required VoidCallback onPressed}) {
    return Column(
      children: [
        Container(
          width: 150,
          height: 170,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              icon,
              size: 80,
              color: Colors.orange, // Placeholder for illustration
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 150,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA5555A), // Dark reddish-brown
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 0,
            ),
            onPressed: onPressed,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
