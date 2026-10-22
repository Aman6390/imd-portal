import 'dart:convert';

/// Represents AI-extracted semantic metadata for an official MetNet circular.
class AiCircularEntry {
  final String id;
  final String title;
  final String url;
  final String date;
  final String section;
  final bool isVip;
  final List<String> vipReasons;
  final String targetCadre;
  final String category;
  final String summaryEn;
  final String summaryHi;
  final bool actionRequired;
  final String source;

  const AiCircularEntry({
    required this.id,
    required this.title,
    required this.url,
    this.date = '',
    this.section = '',
    this.isVip = false,
    this.vipReasons = const [],
    this.targetCadre = 'General / All',
    this.category = 'General',
    this.summaryEn = '',
    this.summaryHi = '',
    this.actionRequired = false,
    this.source = 'rules_fallback',
  });

  factory AiCircularEntry.fromMap(Map<String, dynamic> map) {
    return AiCircularEntry(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      url: map['url'] as String? ?? '',
      date: map['date'] as String? ?? '',
      section: map['section'] as String? ?? '',
      isVip: map['is_vip'] as bool? ?? false,
      vipReasons: (map['vip_reasons'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      targetCadre: map['target_cadre'] as String? ?? 'General / All',
      category: map['category'] as String? ?? 'General',
      summaryEn: map['summary_en'] as String? ?? '',
      summaryHi: map['summary_hi'] as String? ?? '',
      actionRequired: map['action_required'] as bool? ?? false,
      source: map['source'] as String? ?? 'rules_fallback',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'date': date,
      'section': section,
      'is_vip': isVip,
      'vip_reasons': vipReasons,
      'target_cadre': targetCadre,
      'category': category,
      'summary_en': summaryEn,
      'summary_hi': summaryHi,
      'action_required': actionRequired,
      'source': source,
    };
  }

  String toJson() => json.encode(toMap());

  factory AiCircularEntry.fromJson(String source) =>
      AiCircularEntry.fromMap(json.decode(source) as Map<String, dynamic>);
}
