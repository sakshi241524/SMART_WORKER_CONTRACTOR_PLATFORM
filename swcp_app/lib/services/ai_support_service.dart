import 'dart:math';

class AiSupportService {
  final List<Map<String, dynamic>> _knowledgeBase = [
    {
      'keywords': ['photo', 'profile picture', 'image', 'picture', 'change photo', 'upload photo'],
      'answer': 'To change your profile photo, go to "Settings" -> "Personal Information". Tap on the profile icon to pick a new photo from your gallery. Note: Pictures must be under 800KB.',
    },
    {
      'keywords': ['payment', 'money', 'paid', 'salary', 'wage', 'pay'],
      'answer': 'SWCP currently facilitates job matching. Payments are typically handled directly between the contractor and the worker at the site. We recommend discussing rates via our Chat system before starting work.',
    },
    {
      'keywords': ['no jobs', 'not seeing jobs', 'finding jobs', 'work', 'available jobs'],
      'answer': 'If you aren\'t seeing jobs, ensure your status is set to "ACTIVE" on the Dashboard. Also, check that you have added your skills in "Personal Information" so our matching engine can find relevant opportunities for you.',
    },
    {
      'keywords': ['location', 'latitude', 'longitude', 'coordinate', 'map', 'distance'],
      'answer': 'We use your location to match you with jobs within a 10km radius. Your exact location is never shown to others; we only show a general distance (e.g., "within 5km") to protect your privacy.',
    },
    {
      'keywords': ['contractor', 'worker', 'role', 'change role'],
      'answer': 'Your role is selected during registration. To switch between Contractor and Worker roles, you would need to logout and log in with an account registered for that specific role.',
    },
    {
      'keywords': ['skills', 'certificates', 'experience', 'update profile'],
      'answer': 'You can update your skills and certifications in the Profile section. This helps our Smart Match engine find the best high-paying jobs for your specific expertise.',
    },
    {
      'keywords': ['chat', 'message', 'translate', 'talk', 'contact'],
      'answer': 'You can message contractors directly from the "Jobs" tab or see existing conversations in the "Messages" tab. We even support real-time translation for diverse regions!',
    },
    {
      'keywords': ['hi', 'hello', 'hey', 'greetings'],
      'answer': 'Hello! I am your SWCP AI Assistant. I can help you with questions about jobs, payments, profile management, and more. How can I assist you today?',
    },
  ];

  /// Processes user input and returns the most relevant answer from the Knowledge Base.
  Future<String> getResponse(String query) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    final lowerQuery = query.toLowerCase();
    
    // Simple Keyword matching (Mock RAG)
    Map<String, dynamic>? bestMatch;
    int maxMatches = 0;

    for (var entry in _knowledgeBase) {
      int matches = 0;
      final List<String> keywords = entry['keywords'];
      for (var kw in keywords) {
        if (lowerQuery.contains(kw)) {
          matches++;
        }
      }

      if (matches > maxMatches) {
        maxMatches = matches;
        bestMatch = entry;
      }
    }

    if (bestMatch != null && maxMatches > 0) {
      return bestMatch['answer'];
    }

    return "I am not quite sure how to answer that. Could you try rephrasing? You can ask about changing your photo, finding jobs, how payments work, or how we use your location.";
  }
}
