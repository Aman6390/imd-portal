import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_circular_entry.dart';

/// Service responsible for fetching, caching, synthesizing, and matching AI-extracted
/// semantic summaries and cadre tags from central cloud repositories and on-device smart engine.
class AiCircularService {
  static const List<String> _rawIndexUrls = [
    'https://raw.githubusercontent.com/Aman6390/imd-portal/main/data/circulars_ai_index.json',
    'https://raw.githubusercontent.com/Aman6390/imd-portal/feature/ai-circular-indexer/data/circulars_ai_index.json',
  ];
  static const String _cacheKey = 'cached_circulars_ai_index';
  static const String _prefUserEnabledKey = 'pref_enable_ai_summaries';

  static Map<String, AiCircularEntry> _entriesByUrl = {};
  static Map<String, AiCircularEntry> _entriesByNormalizedTitle = {};
  static bool _isKillSwitchActive = false;
  static bool _userEnabled = true;
  static bool _isInitialized = false;

  /// Notifier triggered whenever the index is updated or loaded
  static final ValueNotifier<int> onIndexUpdated = ValueNotifier<int>(0);

  /// Synchronous check if AI features are enabled (UI fast-path)
  static bool isAiEnabledSync() {
    return _userEnabled && !_isKillSwitchActive;
  }

  /// Asynchronous check if AI features are enabled
  static Future<bool> isAiEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    _userEnabled = prefs.getBool(_prefUserEnabledKey) ?? true;
    return isAiEnabledSync();
  }

  /// Toggle user preference for AI summaries
  static Future<void> setUserEnabled(bool enabled) async {
    _userEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefUserEnabledKey, enabled);
    onIndexUpdated.value++;
  }

  /// Initialize and load cached AI metadata from storage or bundled assets on startup
  static Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _userEnabled = prefs.getBool(_prefUserEnabledKey) ?? true;

      // 1. Try loading cached cloud index from SharedPreferences
      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        _parseAndLoadIndex(cachedJson);
      }

      // 2. If cache is empty, load baseline index bundled with the app
      if (_entriesByNormalizedTitle.isEmpty) {
        try {
          final assetData = await rootBundle.loadString('data/circulars_ai_index.json');
          if (assetData.isNotEmpty) {
            _parseAndLoadIndex(assetData);
          }
        } catch (_) {}
      }
    } catch (_) {}
    _isInitialized = true;
    onIndexUpdated.value++;
  }

  /// Fetch latest AI index from GitHub with multi-URL resilience
  static Future<void> syncIndex() async {
    await initialize();

    for (final url in _rawIndexUrls) {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200 && response.body.isNotEmpty) {
          _parseAndLoadIndex(response.body);

          // Cache locally for offline access
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cacheKey, response.body);
          onIndexUpdated.value++;
          break; // Successfully fetched latest index
        }
      } catch (_) {
        // Try next fallback URL if network or DNS fails
      }
    }
  }

  /// Parse the raw JSON index into fast in-memory lookup maps
  static void _parseAndLoadIndex(String rawJson) {
    try {
      final Map<String, dynamic> decoded = json.decode(rawJson);

      // Remote Kill-Switch Check
      final bool globalEnabled = decoded['enable_ai_index'] as bool? ?? true;
      _isKillSwitchActive = !globalEnabled;

      if (_isKillSwitchActive) {
        _entriesByUrl.clear();
        _entriesByNormalizedTitle.clear();
        return;
      }

      final Map<String, dynamic>? circulars =
          decoded['circulars'] as Map<String, dynamic>?;

      if (circulars == null) return;

      final byUrl = <String, AiCircularEntry>{};
      final byTitle = <String, AiCircularEntry>{};

      circulars.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          final entry = AiCircularEntry.fromMap(value);
          if (entry.url.isNotEmpty) {
            byUrl[entry.url.trim().toLowerCase()] = entry;
          }
          final normTitle = _normalizeTitle(entry.title);
          if (normTitle.isNotEmpty) {
            byTitle[normTitle] = entry;
          }
        }
      });

      _entriesByUrl = byUrl;
      _entriesByNormalizedTitle = byTitle;
    } catch (_) {}
  }

  /// Lookup AI semantic metadata for a circular, or synthesize on-the-fly via on-device engine
  static AiCircularEntry? getMetadata(String? url, String? title) {
    if (!isAiEnabledSync()) return null;

    final cleanUrl = url?.trim().toLowerCase() ?? '';
    final normTitle = _normalizeTitle(title ?? '');

    // 1. Cloud-verified entry by URL
    if (cleanUrl.isNotEmpty && _entriesByUrl.containsKey(cleanUrl)) {
      return _entriesByUrl[cleanUrl];
    }

    // 2. Cloud-verified entry by Title
    if (normTitle.isNotEmpty && _entriesByNormalizedTitle.containsKey(normTitle)) {
      return _entriesByNormalizedTitle[normTitle];
    }

    // 3. Failsafe Tier: On-Device Smart Semantic Synthesizer
    if (title != null && title.trim().isNotEmpty) {
      final synthesized = _synthesizeLocalMetadata(url, title.trim());
      if (normTitle.isNotEmpty) {
        _entriesByNormalizedTitle[normTitle] = synthesized;
      }
      if (cleanUrl.isNotEmpty) {
        _entriesByUrl[cleanUrl] = synthesized;
      }
      return synthesized;
    }

    return null;
  }

  /// On-Device Smart Semantic Synthesizer
  /// Performs instant cadre categorization, action detection, VIP flagging, and plain-English summary.
  static AiCircularEntry _synthesizeLocalMetadata(String? url, String title) {
    final t = title.toLowerCase();

    // 1. Cadre Detection with Official IMD Cadre Hierarchy
    final String cadre = _detectCadre(title);
    final String cadreLabel = cadre == 'General / All' ? 'departmental personnel' : cadre;

    // 2. Action Required Detection
    final actionKeywords = [
      'representation',
      'objection',
      'option',
      'proforma',
      'pro-forma',
      'calling for',
      'apply',
      'application',
      'vigilance clearance',
      'nomination',
      'willingness',
      'claims',
      'last date',
      'by 1700',
      'immediate compliance',
      'compliance',
      'अभ्यावेदन',
      'आपत्ति',
      'आवेदन',
      'प्रपत्र'
    ];
    final bool actionRequired = actionKeywords.any((kw) => t.contains(kw));

    // 3. VIP Detection
    final vipKeywords = [
      'seniority',
      'promotion',
      'macp',
      'modified acp',
      'ldce',
      'transfer',
      'posting',
      'working arrangement',
      'lacd',
      'training course',
      'wmo vacancy',
      'vacancy',
      'वरिष्ठता',
      'पदोन्नति',
      'स्थानांतरण',
      'कार्य व्यवस्था'
    ];
    final matchedVip = vipKeywords.where((kw) => t.contains(kw)).toList();
    final bool isVip = matchedVip.isNotEmpty;

    // 4. Clean readable 1-Sentence Summary Generation
    String summary;
    if (actionRequired) {
      summary = 'Action required: Review circular & submit representation or proforma for $cadreLabel before deadline.';
    } else if (t.contains('seniority') || t.contains('वरिष्ठता')) {
      summary = 'Official seniority and gradation list published for $cadreLabel.';
    } else if (t.contains('transfer') ||
        t.contains('posting') ||
        t.contains('working arrangement') ||
        t.contains('स्थानांतरण')) {
      summary = 'Official transfer, posting or working arrangement order for $cadreLabel.';
    } else if (t.contains('promotion') ||
        t.contains('macp') ||
        t.contains('पदोन्नति')) {
      summary = 'Departmental promotion or financial upgradation under MACP scheme for $cadreLabel.';
    } else if (t.contains('training') ||
        t.contains('course') ||
        t.contains('wmo') ||
        t.contains('fellowship')) {
      summary = 'Departmental training course or fellowship nomination notice for $cadreLabel.';
    } else if (t.contains('vigilance') || t.contains('disciplinary')) {
      summary = 'Administrative vigilance governance and compliance directive.';
    } else if (t.contains('holiday') || t.contains('closed')) {
      summary = 'Official notification regarding office operational hours and holidays.';
    } else {
      summary = 'Official departmental order for $cadreLabel: ${_cleanTitleForSummary(title)}';
    }

    final id = _normalizeTitle(title).padRight(16, '0').substring(0, 16);

    return AiCircularEntry(
      id: id,
      title: title,
      url: url ?? '',
      isVip: isVip,
      vipReasons: matchedVip,
      targetCadre: cadre,
      actionRequired: actionRequired,
      summaryEn: summary,
      source: 'device_smart_engine',
    );
  }

  /// Accurate Cadre Detector following Official IMD Cadre Classification
  static String _detectCadre(String title) {
    final t = title.toLowerCase();
    final List<String> cadres = [];

    // 1. Scientists: B to H
    final scientistGrades = ['h', 'g', 'f', 'e', 'd', 'c', 'b'];
    for (final g in scientistGrades) {
      final reg = RegExp('\\b(sc[-. ]*$g|scientist[-. ]*$g)\\b', caseSensitive: false);
      if (reg.hasMatch(t) ||
          t.contains('वैज्ञानिक $g') ||
          t.contains("वैज्ञानिक '$g'")) {
        cadres.add('Scientist ${g.toUpperCase()}');
      }
    }

    // 2. Scientific Officers: SO-I, SO-II, SO-III
    if (RegExp(r'\b(so[-. ]*iii|scientific\s+officer[-. ]*iii|so[-. ]*3)\b', caseSensitive: false).hasMatch(t) ||
        t.contains('वैज्ञानिक अधिकारी-iii') ||
        t.contains('वैज्ञानिक अधिकारी iii') ||
        t.contains('वैज्ञानिक अधिकारी 3')) {
      cadres.add('SO-III');
    }
    if (RegExp(r'\b(so[-. ]*ii|scientific\s+officer[-. ]*ii|so[-. ]*2)\b', caseSensitive: false).hasMatch(t) ||
        t.contains('वैज्ञानिक अधिकारी-ii') ||
        t.contains('वैज्ञानिक अधिकारी ii') ||
        t.contains('वैज्ञानिक अधिकारी 2')) {
      cadres.add('SO-II');
    }
    if (RegExp(r'\b(so[-. ]*i\b|scientific\s+officer[-. ]*i\b|so[-. ]*1\b)', caseSensitive: false).hasMatch(t) ||
        t.contains('वैज्ञानिक अधिकारी-i') ||
        t.contains('वैज्ञानिक अधिकारी i') ||
        t.contains('वैज्ञानिक अधिकारी 1')) {
      cadres.add('SO-I');
    }

    // 3. Meteorologists: Met A and Met B (Check Met B first so Met-I doesn't match prefix of Met-II)
    if (RegExp(r'\b(met[-. ]*b\b|met[-. ]*gr(ade)?[-. ]*b\b|meteorologist[-. ]*b\b|meteorologist[-. ]*gr(ade)?[-. ]*b\b|met[-. ]*ii\b|meteorologist[-. ]*ii\b)', caseSensitive: false).hasMatch(t) ||
        t.contains('मौसम विज्ञानी-ii') ||
        t.contains('मौसम विज्ञानी ii') ||
        t.contains('मौसम विज्ञानी ख') ||
        t.contains('मौसम विज्ञानी b')) {
      cadres.add('Met B');
    }
    if (RegExp(r'\b(met[-. ]*a\b|met[-. ]*gr(ade)?[-. ]*a\b|meteorologist[-. ]*a\b|meteorologist[-. ]*gr(ade)?[-. ]*a\b|met[-. ]*i\b|meteorologist[-. ]*i\b)', caseSensitive: false).hasMatch(t) ||
        t.contains('मौसम विज्ञानी-i') ||
        t.contains('मौसम विज्ञानी i') ||
        t.contains('मौसम विज्ञानी क') ||
        t.contains('मौसम विज्ञानी a')) {
      cadres.add('Met A');
    }

    // 4. Scientific Assistant (SA)
    if (RegExp(r'\b(sa\b|s\.a\.|scientific\s+assistant|ssa\b|sr\.?\s*scientific\s+assistant)', caseSensitive: false).hasMatch(t) ||
        t.contains('वैज्ञानिक सहायक')) {
      cadres.add('Scientific Assistant (SA)');
    }

    // 5. Clerks (UDC / LDC)
    if (RegExp(r'\b(clerk|clerks|udc|ldc|upper\s+division\s+clerk|lower\s+division\s+clerk|clerical)\b', caseSensitive: false).hasMatch(t) ||
        t.contains('लिपिक') ||
        t.contains('यूडीसी') ||
        t.contains('एलडीसी')) {
      cadres.add('Clerk (UDC/LDC)');
    }

    // 6. MTS / Attendant
    if (RegExp(r'\b(mts|multi[- ]tasking|attendant|peon)\b', caseSensitive: false).hasMatch(t) ||
        t.contains('एमटीएस') ||
        t.contains('परिचारक')) {
      cadres.add('MTS / Attendant');
    }

    // 7. Engineering & Technical
    if (RegExp(r'\b(engineer|telecom|instrumentation|draughtsman|workshop)\b', caseSensitive: false).hasMatch(t) ||
        t.contains('अभियंता') ||
        t.contains('तकनीकी')) {
      cadres.add('Engineering / Tech');
    }

    // 8. Finance & Accounts
    if (RegExp(r'\b(finance|account|accounts|ddo|pao|audit|budget)\b', caseSensitive: false).hasMatch(t) ||
        t.contains('लेखा') ||
        t.contains('वित्त')) {
      cadres.add('Finance & Accounts');
    }

    // 9. Fallback generic cadres
    if (cadres.isEmpty) {
      if (RegExp(r'\b(administrative|section\s+officer|steno|stenographer|ministerial)\b', caseSensitive: false).hasMatch(t) ||
          t.contains('प्रशासनिक')) {
        return 'Administrative';
      }
      if (t.contains('scientist') || t.contains('वैज्ञानिक')) {
        return 'Scientist';
      }
      if (t.contains('meteorologist') || t.contains('मौसम विज्ञानी')) {
        return 'Meteorologist';
      }
      return 'General / All';
    }

    return cadres.length == 1 ? cadres.first : cadres.reversed.join(' / ');
  }

  /// Clean title for summary string
  static String _cleanTitleForSummary(String text) {
    var clean = text.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length > 75) {
      clean = '${clean.substring(0, 72)}...';
    }
    return clean;
  }

  /// Normalize circular title by removing punctuation and extra whitespace
  static String _normalizeTitle(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zA-Z0-9\u0900-\u097F]'), '')
        .trim();
  }
}
