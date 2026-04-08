import 'package:flutter/material.dart';
import 'role_selection_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.only(top: 120.0),
                child: Column(
                  children: [
                    const Text(
                      'SmartConnect',
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F3A40), // Dark teal/greenish color
                        letterSpacing: -1.0, 
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'SMART WORKER CONTRACTOR\nPLATFORM',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                        letterSpacing: 2.0,
                        height: 1.5,
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
                        borderRadius: BorderRadius.circular(15), 
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
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
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
