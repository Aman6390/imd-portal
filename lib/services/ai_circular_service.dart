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
    'https://raw.githubusercontent.com/Aman6390/metnet-circulars-index/main/circulars_ai_index.json',
    'https://raw.githubusercontent.com/Aman6390/metnet-circulars-index/main/data/circulars_ai_index.json',
    'https://raw.githubusercontent.com/Aman6390/imd-portal/main/data/circulars_ai_index.json',
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
  /// Checks if a circular has already been indexed in the central cloud index
  static bool hasCloudIndexFor(String? url, String? title) {
    final cleanUrl = url?.trim().toLowerCase() ?? '';
    final normTitle = _normalizeTitle(title ?? '');
    if (cleanUrl.isNotEmpty && _entriesByUrl.containsKey(cleanUrl)) return true;
    if (normTitle.isNotEmpty && _entriesByNormalizedTitle.containsKey(normTitle)) return true;
    return false;
  }

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
  /// Robustly handles quotes (e.g. Sc. 'C'), abbreviations (e.g. Scientific Asstt.), dots (e.g. S.O.-I), and Hindi titles
  static String _detectCadre(String title) {
    final t = title.toLowerCase();
    final List<String> cadres = [];

    // Hindi grade aliases for Scientists
    const hindiScientistMap = {
      'b': ['b', 'बी', 'ख'],
      'c': ['c', 'सी', 'ग'],
      'd': ['d', 'डी', 'घ'],
      'e': ['e', 'ई'],
      'f': ['f', 'एफ'],
      'g': ['g', 'जी'],
      'h': ['h', 'एच'],
    };

    // 1. Scientists: B to H (handles Sc. 'B', Sc.'B', Sc 'B', Scientist 'B', Sc-B, Sc. B, Sc B)
    final scientistGrades = ['b', 'c', 'd', 'e', 'f', 'g', 'h'];
    for (final g in scientistGrades) {
      final reg = RegExp(r'(?:sc|scientist)[.\s-]*[\x27\x22]?\s*' + g + r'\b[\x27\x22]?', caseSensitive: false);
      final hindiVariants = hindiScientistMap[g] ?? [g];
      final hindiMatch = hindiVariants.any((h) =>
          t.contains('वैज्ञानिक $h') ||
          t.contains("वैज्ञानिक '$h'") ||
          t.contains('वैज्ञानिक "$h"') ||
          t.contains('वैज्ञानिक-$h'));
      if (reg.hasMatch(t) || hindiMatch) {
        cadres.add('Scientist ${g.toUpperCase()}');
      }
    }

    // 2. Scientific Officers: SO-I, SO-II, SO-III (handles S.O.-I, S.O. I, SO-I, SO 1, Scientific Officer I)
    if (RegExp(r'\b(?:s\.?\s*o\.?|scientific\s+officer)[-.\s]*(?:i|1)\b', caseSensitive: false).hasMatch(t) ||
        t.contains('वैज्ञानिक अधिकारी-i') ||
        t.contains('वैज्ञानिक अधिकारी i') ||
        t.contains('वैज्ञानिक अधिकारी 1') ||
        t.contains('वैज्ञानिक अधिकारी-1')) {
      cadres.add('SO-I');
    }
    if (RegExp(r'\b(?:s\.?\s*o\.?|scientific\s+officer)[-.\s]*(?:ii|2)\b', caseSensitive: false).hasMatch(t) ||
        t.contains('वैज्ञानिक अधिकारी-ii') ||
        t.contains('वैज्ञानिक अधिकारी ii') ||
        t.contains('वैज्ञानिक अधिकारी 2') ||
        t.contains('वैज्ञानिक अधिकारी-2')) {
      cadres.add('SO-II');
    }
    if (RegExp(r'\b(?:s\.?\s*o\.?|scientific\s+officer)[-.\s]*(?:iii|3)\b', caseSensitive: false).hasMatch(t) ||
        t.contains('वैज्ञानिक अधिकारी-iii') ||
        t.contains('वैज्ञानिक अधिकारी iii') ||
        t.contains('वैज्ञानिक अधिकारी 3') ||
        t.contains('वैज्ञानिक अधिकारी-3')) {
      cadres.add('SO-III');
    }

    // 3. Meteorologists: Met A and Met B (handles Met. 'A', Met 'A', Met-A, AM-I, AM-II, Met. 'B', etc.)
    if (RegExp(r'\b(?:met\.?|meteorologist|am)[-.\s]*(?:gr(?:ade)?\.?[-.\s]*)?[\x27\x22]?\s*(?:a|i)\b[\x27\x22]?', caseSensitive: false).hasMatch(t) ||
        t.contains('मौसम विज्ञानी-i') ||
        t.contains('मौसम विज्ञानी i') ||
        t.contains('मौसम विज्ञानी क') ||
        t.contains('मौसम विज्ञानी a')) {
      cadres.add('Met A');
    }
    if (RegExp(r'\b(?:met\.?|meteorologist|am)[-.\s]*(?:gr(?:ade)?\.?[-.\s]*)?[\x27\x22]?\s*(?:b|ii)\b[\x27\x22]?', caseSensitive: false).hasMatch(t) ||
        t.contains('मौसम विज्ञानी-ii') ||
        t.contains('मौसम विज्ञानी ii') ||
        t.contains('मौसम विज्ञानी ख') ||
        t.contains('मौसम विज्ञानी b')) {
      cadres.add('Met B');
    }

    // 4. Scientific Assistant (SA) (handles SA, S.A., S.A.(Met), Scientific Asstt, Sci Asstt, Sc Asstt)
    if (RegExp(r'\b(?:s\.?\s*a\.?|ssa|scientific\s+asstt?\.?|sci\.?\s*asstt?\.?|sc\.?\s*asstt?\.?|scientific\s+assistant)\b', caseSensitive: false).hasMatch(t) ||
        t.contains('वैज्ञानिक सहायक')) {
      cadres.add('Scientific Assistant (SA)');
    }

    // 5. Clerks (UDC / LDC / Clerical)
    if (RegExp(r'\b(?:clerk|clerks|udc|ldc|upper\s+div\w*\s+clerk|lower\s+div\w*\s+clerk|clerical)\b', caseSensitive: false).hasMatch(t) ||
        t.contains('लिपिक') ||
        t.contains('यूडीसी') ||
        t.contains('एलडीसी')) {
      cadres.add('Clerk (UDC/LDC)');
    }

    // 6. MTS / Attendant
    if (RegExp(r'\b(?:mts|multi[- ]tasking|attendant|peon)\b', caseSensitive: false).hasMatch(t) ||
        t.contains('एमटीएस') ||
        t.contains('परिचारक')) {
      cadres.add('MTS / Attendant');
    }

    // 7. Engineering & Technical
    if (RegExp(r'\b(?:engineer|telecom|instrumentation|draughtsman|workshop)\b', caseSensitive: false).hasMatch(t) ||
        t.contains('अभियंता') ||
        t.contains('तकनीकी')) {
      cadres.add('Engineering / Tech');
    }

    // 8. Finance & Accounts
    if (RegExp(r'\b(?:finance|account|accounts|ddo|pao|audit|budget)\b', caseSensitive: false).hasMatch(t) ||
        t.contains('लेखा') ||
        t.contains('वित्त')) {
      cadres.add('Finance & Accounts');
    }

    // 9. Fallback generic cadres
    if (cadres.isEmpty) {
      if (RegExp(r'\b(?:administrative|section\s+officer|steno\w*|ministerial)\b', caseSensitive: false).hasMatch(t) ||
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

    return cadres.join(' / ');
  }

  /// Generates a structured plain-language breakdown for an expanded summary view
  static Map<String, String> getPlainLanguageBreakdown(AiCircularEntry? meta, String title) {
    final t = title.toLowerCase();
    final cadre = (meta?.targetCadre != null && meta!.targetCadre.isNotEmpty && meta.targetCadre != 'General / All')
        ? meta.targetCadre
        : _detectCadre(title);
    final cadreLabel = cadre == 'General / All' ? 'departmental personnel' : cadre;

    String meaning;
    String action;
    String jargon = '';

    if (t.contains('seniority') || t.contains('gradation') || t.contains('वरिष्ठता')) {
      meaning = 'The department has prepared the official seniority ranking list for ' + cadreLabel + '. This list determines career progression and future promotion order.';
      action = 'Check where your name and seniority number appear. Verify your date of birth and joining date.';
      jargon = 'Seniority List = Official rank by batch & service length that governs promotion sequence.';
    } else if (t.contains('transfer') || t.contains('posting') || t.contains('स्थानांतरण')) {
      meaning = 'Official transfer or station posting orders issued for ' + cadreLabel + ' across meteorological stations/observatories.';
      action = 'Review the station relocation list and compliance instructions for taking charge at new station.';
    } else if (t.contains('working arrangement') || t.contains('lacd') || t.contains('charge') || t.contains('कार्य व्यवस्था')) {
      meaning = 'Interim administrative working arrangement assigning additional supervisory duties or charge for ' + cadreLabel + '.';
      action = 'For personnel assigned charge: ensure formal assumption of duties and submit assumption report.';
      jargon = 'LACD = Looking After Current Duties (temporary additional responsibility without pay change).';
    } else if (t.contains('promotion') || t.contains('पदोन्नति')) {
      meaning = 'Official departmental order granting career promotion to the next grade for eligible ' + cadreLabel + ' officers.';
      action = 'Verify effective date of promotion and formal assumption of higher charge for pay fixation.';
    } else if (t.contains('macp') || t.contains('modified acp')) {
      meaning = 'Financial pay-scale upgrade granted under the MACP scheme to ' + cadreLabel + ' personnel upon completing qualifying service years.';
      action = 'Verify the upgraded pay matrix level and option submission for pay fixation within one month.';
      jargon = 'MACP = Modified Assured Career Progression (financial upgrade after 10, 20, or 30 years).';
    } else if (t.contains('wmo') || t.contains('training') || t.contains('course') || t.contains('fellowship')) {
      meaning = 'Departmental notification calling for nominations or applications for specialized meteorological training or WMO fellowships.';
      action = 'Check eligibility conditions and forward application through your controlling officer before deadline.';
    } else if (t.contains('ldce') || t.contains('exam') || t.contains('examination')) {
      meaning = 'Limited Departmental Competitive Examination (LDCE) notification, syllabus, or candidate shortlist.';
      action = 'Review exam schedule, eligibility cutoff, and submit verification proforma through proper channel.';
      jargon = 'LDCE = Limited Departmental Competitive Examination (accelerated quota promotion test).';
    } else if (t.contains('vigilance') || t.contains('disciplinary') || t.contains('conduct')) {
      meaning = 'Administrative compliance and integrity directive from the Vigilance Division for all personnel.';
      action = 'Review compliance requirements. Ensure timely submission of annual property returns or disclosures if indicated.';
    } else if (t.contains('holiday') || t.contains('closed')) {
      meaning = 'Official notification regarding administrative working days, closed holidays, or restricted holidays.';
      action = 'Note down the holiday schedule for station duty planning and shift rosters.';
    } else {
      final clean = _cleanTitleForSummary(title);
      meaning = 'Official administrative circular published by IMD administration concerning ' + cadreLabel + ': ' + clean;
      action = 'Read through document for general departmental awareness and operational guidance.';
    }

    if (meta?.actionRequired == true ||
        t.contains('representation') ||
        t.contains('objection') ||
        t.contains('proforma') ||
        t.contains('calling for')) {
      action = 'Action Required: Check if you are affected. If you have objections or wish to represent, submit your representation through your Station Head before the cutoff date.';
      if (jargon.isEmpty) {
        jargon = 'Representation = Official written submission/objection routed via controlling officer.';
      }
    }

    return {
      'meaning': meaning,
      'action': action,
      'jargon': jargon,
    };
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
