/// Static bilingual translation map for SignBridge.
///
/// Supports English ('en') and Swahili ('sw').
/// Falls back to English, then to the raw key if no match is found.
class AppTranslations {
  AppTranslations._(); // prevent instantiation

  /// Look up [key] for the given [langCode].
  /// Falls back: requested lang → English → raw key.
  static String t(String key, String langCode) {
    return _values[langCode]?[key] ?? _values['en']?[key] ?? key;
  }

  static const Map<String, Map<String, String>> _values = {
    // ────────────────────────── ENGLISH ──────────────────────────
    'en': {
      // Onboarding
      'onboarding.skip': 'Skip',
      'onboarding.next': 'Next',
      'onboarding.get_started': 'Get Started',
      'onboarding.welcome_title': 'Welcome to SignBridge',
      'onboarding.welcome_desc':
          'A two-way sign language recognition and speech translation system. '
          'Bridging communication between deaf and hearing users in real-time.',
      'onboarding.video_title': 'Real-Time Video Calls',
      'onboarding.video_desc':
          'Create or join a video call with a unique Call ID. '
          'Share the ID with your peer to connect instantly. '
          'AI translation runs on your device — no internet required for processing.',
      'onboarding.ai_title': 'AI-Powered Translation',
      'onboarding.ai_desc':
          'Sign language gestures are recognized and converted to text and speech. '
          'Spoken words are converted to text and sign language GIFs. '
          'All processing happens on your phone!',
      'onboarding.access_title': 'Adaptive Accessibility',
      'onboarding.access_desc':
          'Choose your role — Deaf, Hearing, or Both — and the app adapts automatically. '
          'Visual captions, sign language GIFs, voice controls, and visual notifications '
          'adjust to your needs.',

      // Login
      'login.title_login': 'Log In',
      'login.title_signup': 'Sign Up',
      'login.email': 'Email',
      'login.password': 'Password',
      'login.name': 'Display Name',
      'login.google': 'Continue with Google',
      'login.guest': 'Continue as Guest',
      'login.switch_to_signup': "Don't have an account? Sign Up",
      'login.switch_to_login': 'Already have an account? Log In',
      'login.or': 'OR',
      'login.fill_fields': 'Please fill all required fields',
      'login.name_required': 'Name is required for Sign Up',
      'login.select_role': 'Select your role',
      'login.signbridge_id': 'SignBridge ID (Username)',
      'login.id_invalid': 'SignBridge ID must be 3-15 alphanumeric chars or underscores',

      // Home
      'home.welcome': 'Welcome',
      'home.subtitle':
          'Start an inclusive video call with real-time translation.',
      'home.your_id': 'Your ID:',
      'home.id_copied': 'User ID copied!',
      'home.create_call': 'Create Call',
      'home.create_call_sub': 'Start a new call and share the ID',
      'home.join_call': 'Join Call',
      'home.join_call_sub': 'Enter a call ID to join',
      'home.history': 'Translation History',
      'home.history_sub': 'View past conversations',
      'home.learning': 'Learning Resources',
      'home.learning_sub': 'Sign language guides & materials',
      'home.recent_calls': 'Recent Calls',
      'home.clear': 'Clear',
      'home.call_id': 'Call ID',
      'home.call_id_hint': 'Paste the call ID here',
      'home.cancel': 'Cancel',
      'home.join': 'Join',

      // Settings
      'settings.title': 'Settings',
      'settings.profile': 'Profile',
      'settings.role': 'Accessibility Role',
      'settings.role_desc':
          'Select your communication role to personalise the experience.',
      'settings.deaf': 'Deaf',
      'settings.hearing': 'Hearing',
      'settings.both': 'Both',
      'settings.appearance': 'Appearance',
      'settings.theme': 'Theme',
      'settings.captions': 'Captions & Subtitles',
      'settings.enable_captions': 'Enable Captions',
      'settings.captions_desc':
          'Show real-time subtitles during calls',
      'settings.caption_size': 'Caption Font Size',
      'settings.notifications': 'Notifications',
      'settings.visual_notif': 'Visual Notifications',
      'settings.visual_notif_desc':
          'Use vibration and flash instead of audio alerts',
      'settings.about': 'About',
      'settings.version': 'Version',
      'settings.developer': 'Developer',
      'settings.developer_name': 'Developed by Sir Kelvin Mbise',
      'settings.language': 'Language',
      'settings.language_desc': 'Choose your preferred app language',

      // Call Screen
      'call.connecting': 'Connecting...',
      'call.waiting': 'Waiting for peer...',
      'call.connected': 'Connected',
      'call.ended': 'Call Ended',
      'call.share_id': 'Share this Call ID:',
      'call.copied': 'Call ID copied!',
      'call.end': 'End Call',
      'call.error': 'Call Error',
      'call.sim_title': 'AI Simulator (Test Helper)',
      'call.sim_gesture': 'Simulate Gesture',
      'call.sim_gesture_desc': 'Spoken via TTS and synced to both devices',
      'call.sim_speech': 'Simulate Speech',
      'call.sim_speech_desc': 'Synced as captions & GIF without speaking aloud',

      // History Screen
      'history.title': 'Translation History',
      'history.search': 'Search translations...',
      'history.no_results': 'No translations found',
      'history.empty': 'No translation history yet',
      'history.empty_desc': 'Your call translations will appear here',
      'history.clear': 'Clear History',
      'history.clear_confirm': 'Clear all history?',
      'history.gesture': 'Gesture',
      'history.speech': 'Speech',

      // Learning Screen
      'learning.title': 'Learning Resources',
      'learning.search': 'Search resources...',
      'learning.open_pdf': 'Open Resource',

      // Common / General
      'common.error': 'Error',
      'common.ok': 'OK',
      'common.yes': 'Yes',
      'common.no': 'No',
      'common.loading': 'Loading...',
      'common.retry': 'Retry',

      // Nav bar
      'nav.home': 'Home',
      'nav.history': 'History',
      'nav.learn': 'Learn',
      'nav.settings': 'Settings',

      // Contacts
      'contacts.title': 'Saved Contacts',
      'contacts.sub': 'Save peer IDs for quick calls',
      'contacts.add': 'Add Contact',
      'contacts.name': 'Contact Name',
      'contacts.name_hint': 'Enter name',
      'contacts.id': 'User ID',
      'contacts.id_hint': 'Enter short ID',
      'contacts.role': 'Role',
      'contacts.empty': 'No saved contacts yet',
      'contacts.delete_confirm': 'Delete this contact?',
      'contacts.save': 'Save',
      'settings.contact_support': 'Contact Support',
    },

    // ────────────────────────── SWAHILI ──────────────────────────
    'sw': {
      // Onboarding
      'onboarding.skip': 'Ruka',
      'onboarding.next': 'Endelea',
      'onboarding.get_started': 'Anza Sasa',
      'onboarding.welcome_title': 'Karibu kwenye SignBridge',
      'onboarding.welcome_desc':
          'Mfumo wa kutambua lugha ya ishara na kutafsiri usemi kwa njia mbili. '
          'Kuunganisha mawasiliano kati ya watumiaji wasiosikia na wanaosikia kwa wakati halisi.',
      'onboarding.video_title': 'Simu za Video za Wakati Halisi',
      'onboarding.video_desc':
          'Unda au jiunge na simu ya video kwa Kitambulisho cha Simu. '
          'Shiriki kitambulisho na mwenzako kuunganisha papo hapo. '
          'Tafsiri ya AI inafanya kazi kwenye kifaa chako — hakuna intaneti inayohitajika.',
      'onboarding.ai_title': 'Tafsiri ya AI',
      'onboarding.ai_desc':
          'Ishara za lugha ya ishara zinatambuliwa na kubadilishwa kuwa maandishi na usemi. '
          'Maneno yanayosemwa yanabadilishwa kuwa maandishi na GIF za lugha ya ishara. '
          'Uchakataji wote unafanyika kwenye simu yako!',
      'onboarding.access_title': 'Ufikivu Unaobadilika',
      'onboarding.access_desc':
          'Chagua jukumu lako — Kiziwi, Kusikia, au Vyote — na programu inabadilika kiotomatiki. '
          'Manukuu ya kuona, GIF za lugha ya ishara, vidhibiti vya sauti, na arifa za kuona '
          'zinabadilika kulingana na mahitaji yako.',

      // Login
      'login.title_login': 'Ingia',
      'login.title_signup': 'Jisajili',
      'login.email': 'Barua pepe',
      'login.password': 'Neno la siri',
      'login.name': 'Jina la kuonyesha',
      'login.google': 'Endelea na Google',
      'login.guest': 'Endelea kama Mgeni',
      'login.switch_to_signup': 'Huna akaunti? Jisajili',
      'login.switch_to_login': 'Una akaunti? Ingia',
      'login.or': 'AU',
      'login.fill_fields': 'Tafadhali jaza sehemu zote zinazohitajika',
      'login.name_required': 'Jina linahitajika kwa Usajili',
      'login.select_role': 'Chagua jukumu lako',
      'login.signbridge_id': 'Kitambulisho cha SignBridge',
      'login.id_invalid': 'Kitambulisho kiwe na herufi/namba 3-15 au mistari ya chini pekee',

      // Home
      'home.welcome': 'Karibu',
      'home.subtitle':
          'Anza simu ya video jumuishi na tafsiri ya wakati halisi.',
      'home.your_id': 'Kitambulisho chako:',
      'home.id_copied': 'Kitambulisho kimenakiliwa!',
      'home.create_call': 'Unda Simu',
      'home.create_call_sub': 'Anza simu mpya na ushiriki kitambulisho',
      'home.join_call': 'Jiunge na Simu',
      'home.join_call_sub': 'Weka kitambulisho cha simu kujiunge',
      'home.history': 'Historia ya Tafsiri',
      'home.history_sub': 'Angalia mazungumzo yaliyopita',
      'home.learning': 'Rasilimali za Kujifunza',
      'home.learning_sub': 'Miongozo na nyenzo za lugha ya ishara',
      'home.recent_calls': 'Simu za Hivi Karibuni',
      'home.clear': 'Futa',
      'home.call_id': 'Kitambulisho cha Simu',
      'home.call_id_hint': 'Bandika kitambulisho cha simu hapa',
      'home.cancel': 'Ghairi',
      'home.join': 'Jiunge',

      // Settings
      'settings.title': 'Mipangilio',
      'settings.profile': 'Wasifu',
      'settings.role': 'Jukumu la Ufikivu',
      'settings.role_desc':
          'Chagua jukumu lako la mawasiliano kuboresha uzoefu.',
      'settings.deaf': 'Kiziwi',
      'settings.hearing': 'Kusikia',
      'settings.both': 'Vyote',
      'settings.appearance': 'Muonekano',
      'settings.theme': 'Mandhari',
      'settings.captions': 'Manukuu na Tafsiri',
      'settings.enable_captions': 'Washa Manukuu',
      'settings.captions_desc':
          'Onyesha manukuu ya wakati halisi wakati wa simu',
      'settings.caption_size': 'Ukubwa wa Fonti ya Manukuu',
      'settings.notifications': 'Arifa',
      'settings.visual_notif': 'Arifa za Kuona',
      'settings.visual_notif_desc':
          'Tumia mtetemo na mwanga badala ya arifa za sauti',
      'settings.about': 'Kuhusu',
      'settings.version': 'Toleo',
      'settings.developer': 'Msanidi',
      'settings.developer_name': 'Imetengenezwa na Bwana Kelvin Mbise',
      'settings.language': 'Lugha',
      'settings.language_desc': 'Chagua lugha unayoipendelea',

      // Call Screen
      'call.connecting': 'Inaunganisha...',
      'call.waiting': 'Inasubiri mwenzako...',
      'call.connected': 'Imeunganishwa',
      'call.ended': 'Simu Imeisha',
      'call.share_id': 'Shiriki Kitambulisho hiki cha Simu:',
      'call.copied': 'Kitambulisho cha Simu kimenakiliwa!',
      'call.end': 'Maliza Simu',
      'call.error': 'Hitilafu ya Simu',
      'call.sim_title': 'Kigaia cha AI (Msaidizi)',
      'call.sim_gesture': 'Iga Ishara',
      'call.sim_gesture_desc': 'Inanongonwa na TTS na kusawazishwa kwa vifaa vyote',
      'call.sim_speech': 'Iga Usemi',
      'call.sim_speech_desc': 'Inasawazishwa kama manukuu na GIF bila sauti',

      // History Screen
      'history.title': 'Historia ya Tafsiri',
      'history.search': 'Tafuta tafsiri...',
      'history.no_results': 'Hakuna tafsiri zilizopatikana',
      'history.empty': 'Hakuna historia ya tafsiri bado',
      'history.empty_desc': 'Tafsiri za simu zako zitaonekana hapa',
      'history.clear': 'Futa Historia',
      'history.clear_confirm': 'Futa historia yote?',
      'history.gesture': 'Ishara',
      'history.speech': 'Usemi',

      // Learning Screen
      'learning.title': 'Rasilimali za Kujifunza',
      'learning.search': 'Tafuta rasilimali...',
      'learning.open_pdf': 'Fungua Rasilimali',

      // Common / General
      'common.error': 'Hitilafu',
      'common.ok': 'Sawa',
      'common.yes': 'Ndiyo',
      'common.no': 'Hapana',
      'common.loading': 'Inapakia...',
      'common.retry': 'Jaribu tena',

      // Nav bar
      'nav.home': 'Nyumbani',
      'nav.history': 'Historia',
      'nav.learn': 'Jifunze',
      'nav.settings': 'Mipangilio',

      // Contacts
      'contacts.title': 'Mawasiliano',
      'contacts.sub': 'Hifadhi vitambulisho kwa simu za haraka',
      'contacts.add': 'Ongeza Mawasiliano',
      'contacts.name': 'Jina la Wasifu',
      'contacts.name_hint': 'Weka jina',
      'contacts.id': 'Kitambulisho',
      'contacts.id_hint': 'Weka kitambulisho cha kifupi',
      'contacts.role': 'Jukumu',
      'contacts.empty': 'Hakuna mawasiliano bado',
      'contacts.delete_confirm': 'Futa mawasiliano haya?',
      'contacts.save': 'Hifadhi',
      'settings.contact_support': 'Wasiliana na Huduma',
    },
  };
}
