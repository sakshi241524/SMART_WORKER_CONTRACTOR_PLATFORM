import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Account Settings", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text("Appearance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
            child: ListTile(
              leading: Icon(
                appState.themeMode == ThemeMode.light ? Icons.light_mode : Icons.dark_mode,
                color: Colors.amber,
              ),
              title: const Text("Dark Theme"),
              subtitle: const Text("Toggle between light and dark mode"),
              trailing: Switch(
                value: appState.themeMode == ThemeMode.dark,
                onChanged: (value) => appState.toggleTheme(),
                activeColor: const Color(0xFF0F3A40),
              ),
            ),
          ),
          const SizedBox(height: 30),
          const Text("Language", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 10),
          _buildLanguageOption(context, appState, "English", "en"),
          _buildLanguageOption(context, appState, "हिंदी (Hindi)", "hi"),
          _buildLanguageOption(context, appState, "मराठी (Marathi)", "mr"),
          const SizedBox(height: 20),
          const Text(
            "Note: Language changes are applied immediately using our localization API logic.",
            style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(BuildContext context, AppState appState, String label, String code) {
    final isSelected = appState.locale.languageCode == code;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? const Color(0xFF0F3A40) : Colors.grey.shade200, width: isSelected ? 2 : 1),
      ),
      child: ListTile(
        title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF0F3A40)) : null,
        onTap: () => appState.setLocale(code),
      ),
    );
  }
}
