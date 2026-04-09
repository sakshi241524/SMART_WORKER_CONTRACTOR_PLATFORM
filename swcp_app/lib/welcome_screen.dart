import 'package:flutter/material.dart';
import 'role_selection_screen.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Record this as the last visited guest route
    Future.microtask(() {
      Provider.of<AppState>(context, listen: false).setLastGuestRoute('Welcome');
    });

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFC), // Very light grey/white background
      body: SafeArea(
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFFFAFAFA), // Fallback background color
            image: DecorationImage(
              // NOTE: Add your image file to an 'assets' folder and update pubspec.yaml
              image: AssetImage('assets/firstpage.jpg'), 
              fit: BoxFit.cover,
              opacity: 0.15, // Blends the image so the text remains readable like your mockup
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top Section: Title & Subtitle spaced down from the top
              Padding(
                padding: const EdgeInsets.only(top: 100.0),
                child: Column(
                  children: [
                    const Text(
                      'SmartConnect',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F3A40), // Dark teal/greenish color
                        letterSpacing: -1.0, 
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'SMART WORKER CONTRACTOR\nPLATFORM',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                        letterSpacing: 3.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Section: Get Started Button
              Padding(
                padding: const EdgeInsets.only(bottom: 60.0, left: 30.0, right: 30.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9B9D), // Light coral/pink
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20), 
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                      );
                    },
                    child: const Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
