import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'welcome_screen.dart';
import 'contractor_dashboard.dart';
import 'worker_dashboard.dart';
import 'role_selection_screen.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    if (appState.shouldShowWelcome) {
      return const WelcomeScreen();
    }
    return const RoleSelectionScreen();
  }
}
