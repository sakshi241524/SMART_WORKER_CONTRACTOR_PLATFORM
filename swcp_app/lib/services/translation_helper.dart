class TranslationHelper {
  static final Map<String, Map<String, String>> _dictionary = {
    // Standard System Messages
    'has joined your job': {
      'hi': 'आपके काम में शामिल हो गया है',
      'mr': 'तुमच्या कामात सामील झाला आहे',
    },
    'New Job:': {
      'hi': 'नया काम:',
      'mr': 'नवीन काम:',
    },
    'You have a new job invitation': {
      'hi': 'आपके पास एक नया काम का निमंत्रण है',
      'mr': 'तुमच्याकडे नवीन कामाचे निमंत्रण आहे',
    },
    'Direct Job offer:': {
      'hi': 'सीधा काम का प्रस्ताव:',
      'mr': 'थेट कामाची ऑफर:',
    },
    'You have received a direct job offer. Tap to view details.': {
      'hi': 'आपको एक सीधा काम का प्रस्ताव मिला है। विवरण देखने के लिए टैप करें।',
      'mr': 'तुम्हाला थेट कामाची ऑफर मिळाली आहे. तपशील पाहण्यासाठी टॅप करा.',
    },
    'Journey started! Sharing live location with contractor.': {
      'hi': 'यात्रा शुरू! ठेकेदार के साथ लाइव लोकेशन साझा की जा रही है।',
      'mr': 'प्रवास सुरू झाला! कंत्राटदारासह थेट स्थान सामायिक करत आहे.',
    },
    'I Have Arrived / Stop Tracking': {
      'hi': 'मैं पहुँच गया हूँ / ट्रैकिंग बंद करें',
      'mr': 'मी पोहोचलो आहे / ट्रॅकिंग थांबवा',
    },
    'Track Live': {
      'hi': 'लाइव ट्रैक करें',
      'mr': 'थेट ट्रॅक करा',
    },
    'On the way to job site': {
      'hi': 'काम की जगह की ओर जा रहे हैं',
      'mr': 'कामाच्या ठिकाणी जात आहे',
    },
    'Last updated:': {
      'hi': 'अंतिम अपडेट:',
      'mr': 'शेवटचे अपडेट:',
    },
    'Job rejected': {
      'hi': 'काम अस्वीकार कर दिया गया',
      'mr': 'काम नाकारले',
    },
    'Job accepted successfully!': {
      'hi': 'काम सफलतापूर्वक स्वीकार कर लिया गया!',
      'mr': 'काम यशस्वीरित्या स्वीकारले गेले!',
    },
    'New Job invitation': {
      'hi': 'नए काम का निनिमंत्रण',
      'mr': 'नवीन कामाचे निमंत्रण',
    },
    'has joined your job:': {
      'hi': 'आपके काम में शामिल हो गया है:',
      'mr': 'तुमच्या कामात सामील झाला आहे:',
    },
    'No alerts yet': {
      'hi': 'अभी तक कोई अलर्ट नहीं',
      'mr': 'अद्याप कोणतीही सूचना नाही',
    },
    'Respond': {
      'hi': 'जवाब दें',
      'mr': 'प्रतिसाद द्या',
    },
    'Message': {
      'hi': 'संदेश',
      'mr': 'संदेश',
    },
    'View Details': {
      'hi': 'विवरण देखें',
      'mr': 'तपशील पहा',
    },
    'Notifications': {
      'hi': 'सूचनाएं',
      'mr': 'सूचना',
    },
    'Close Job?': {
      'hi': 'काम बंद करें?',
      'mr': 'काम बंद करायचे का?',
    },
  };

  static String translate(String text, String lang) {
    if (lang == 'en' || lang.isEmpty) return text;
    
    String translated = text;

    // Check for partial or full matches in the dictionary
    _dictionary.forEach((english, translations) {
      if (text.contains(english)) {
        translated = translated.replaceAll(english, translations[lang] ?? english);
      }
    });

    // Fallback prefixes if no specific translation found
    if (translated == text) {
      if (lang == 'hi') return "हिन्दी: $text";
      if (lang == 'mr') return "मराठी: $text";
    }

    return translated;
  }
}
