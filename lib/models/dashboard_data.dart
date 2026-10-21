import 'dart:convert';

class CircularItem {
  final String title;
  final String link;
  final String date;
  bool isUnavailable;
  String? cachedPath;

  CircularItem({
    required this.title,
    required this.link,
    required this.date,
    this.isUnavailable = false,
    this.cachedPath,
  });

  factory CircularItem.fromJson(Map<String, dynamic> json) {
    return CircularItem(
      title: json['title'] ?? '',
      link: json['link'] ?? '',
      date: json['date'] ?? '',
      isUnavailable: json['isUnavailable'] == true,
      cachedPath: json['cachedPath'],
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'link': link,
        'date': date,
        'isUnavailable': isUnavailable,
        'cachedPath': cachedPath,
      };
}

class LapsingAlert {
  final String creditDate;
  final String expiryDate;
  final int daysLeft;

  LapsingAlert({
    required this.creditDate,
    required this.expiryDate,
    required this.daysLeft,
  });

  factory LapsingAlert.fromJson(Map<String, dynamic> json) {
    return LapsingAlert(
      creditDate: json['Credit Date'] ?? '',
      expiryDate: json['Expiry Date'] ?? '',
      daysLeft: json['Days Left'] is int
          ? json['Days Left']
          : int.tryParse(json['Days Left']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'Credit Date': creditDate,
        'Expiry Date': expiryDate,
        'Days Left': daysLeft,
      };
}

class DashboardData {
  final String lastUpdated;
  final Map<String, String> leaves;
  final List<LapsingAlert> alerts;
  final List<CircularItem> vipCirculars;
  final List<CircularItem> fomoCirculars;

  DashboardData({
    required this.lastUpdated,
    required this.leaves,
    required this.alerts,
    required this.vipCirculars,
    required this.fomoCirculars,
  });

  String get clBalance => leaves['Casual Leave (CL)'] ?? '0';
  String get rhBalance => leaves['Restricted Holiday (RH)'] ?? '0';
  String get coffBalance => leaves['Compensatory Off (C-Off)'] ?? '0';

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final leavesMap = <String, String>{};
    if (json['leaves'] is Map) {
      (json['leaves'] as Map).forEach((k, v) {
        leavesMap[k.toString()] = v.toString();
      });
    }

    final alertsList = <LapsingAlert>[];
    if (json['alerts'] is List) {
      for (final item in json['alerts']) {
        if (item is Map<String, dynamic>) {
          alertsList.add(LapsingAlert.fromJson(item));
        }
      }
    }

    final vipList = <CircularItem>[];
    final fomoList = <CircularItem>[];
    if (json['circulars'] is Map) {
      final circMap = json['circulars'] as Map;
      if (circMap['vip'] is List) {
        for (final item in circMap['vip']) {
          if (item is Map<String, dynamic>) {
            vipList.add(CircularItem.fromJson(item));
          }
        }
      }
      if (circMap['fomo'] is List) {
        for (final item in circMap['fomo']) {
          if (item is Map<String, dynamic>) {
            fomoList.add(CircularItem.fromJson(item));
          }
        }
      }
    }

    return DashboardData(
      lastUpdated: json['last_updated'] ?? '',
      leaves: leavesMap,
      alerts: alertsList,
      vipCirculars: vipList,
      fomoCirculars: fomoList,
    );
  }

  Map<String, dynamic> toJson() => {
        'last_updated': lastUpdated,
        'leaves': leaves,
        'alerts': alerts.map((a) => a.toJson()).toList(),
        'circulars': {
          'vip': vipCirculars.map((c) => c.toJson()).toList(),
          'fomo': fomoCirculars.map((c) => c.toJson()).toList(),
        },
      };

  String serialize() => jsonEncode(toJson());

  static DashboardData? deserialize(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr);
      return DashboardData.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}
