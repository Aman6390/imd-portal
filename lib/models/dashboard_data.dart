import 'dart:convert';
import 'package:intl/intl.dart';

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

class LeaveHistoryItem {
  final int slNo;
  final String leaveType; // 'Casual Leave', 'Restricted Holiday', 'Compensatory Off'
  final String applicationDate; // dd-MM-yyyy
  final String leaveDate; // dd-MM-yyyy
  final String duration; // e.g. "1 DAY", "0.5 DAY"
  final String reason; // e.g. "URGENT DOMESTIC WORK"
  final String? slpAddress; // Station Leaving Permission Address
  final String status; // 'Approved & Availed', 'Self Cancellation', 'Auto Cancellation', 'Pending'
  final String actionBy; // Approving Officer Name
  final String? actionRemarks; // Remarks e.g. "Approved", "By mistake", "Due Change in plans!"

  LeaveHistoryItem({
    required this.slNo,
    required this.leaveType,
    required this.applicationDate,
    required this.leaveDate,
    required this.duration,
    required this.reason,
    this.slpAddress,
    required this.status,
    required this.actionBy,
    this.actionRemarks,
  });

  bool get isCancelled {
    final s = status.toLowerCase();
    return s.contains('cancel') || s.contains('reject');
  }

  bool get isApproved {
    final s = status.toLowerCase();
    if (s.contains('pending')) return false;
    return s.contains('approved') || s.contains('availed') || s.contains('sanctioned');
  }

  bool get isPending {
    final s = status.toLowerCase();
    return s.contains('pending');
  }

  /// Returns true only if this is a genuine leave application/availed record
  /// and not an administrative duty credit/shift log entry.
  bool get isGenuineLeave {
    final cleanLeave = leaveDate.trim();
    if (cleanLeave.isEmpty) return false;

    // 1. Must contain an identifiable calendar date pattern (e.g. 03-09-2026, 03/09/2026, 03-Sep-2026)
    final hasDatePattern = RegExp(r'\d{1,2}[-/. ]\d{1,2}[-/. ]\d{2,4}').hasMatch(cleanLeave) ||
        RegExp(r'\d{1,2}[-/. ][A-Za-z]+[-/. ]\d{2,4}').hasMatch(cleanLeave);
    if (!hasDatePattern) return false;

    // 2. Reject any administrative duty credit entries (e.g. night duties, weekend duties, duty credit ledgers)
    final r = reason.toLowerCase();
    final rem = (actionRemarks ?? '').toLowerCase();
    final d = cleanLeave.toLowerCase();

    if (r.contains('in lieu of duty') ||
        r.contains('compensatory off duty') ||
        r.contains('duty credit') ||
        r.contains('duty details') ||
        r.contains('night duty') ||
        r.contains('general shift') ||
        r.contains('shift duty') ||
        d.contains('duty') ||
        d.contains('shift') ||
        rem.contains('duty credit')) {
      return false;
    }

    return true;
  }

  DateTime? get parsedLeaveDate {
    try {
      final clean = leaveDate.trim();
      return DateFormat('dd-MM-yyyy').parse(clean);
    } catch (_) {
      return null;
    }
  }

  DateTime? get parsedApplicationDate {
    try {
      final clean = applicationDate.trim();
      return DateFormat('dd-MM-yyyy').parse(clean);
    } catch (_) {
      return null;
    }
  }

  factory LeaveHistoryItem.fromJson(Map<String, dynamic> json) {
    return LeaveHistoryItem(
      slNo: json['slNo'] is int
          ? json['slNo']
          : int.tryParse(json['slNo']?.toString() ?? '0') ?? 0,
      leaveType: json['leaveType'] ?? 'Casual Leave',
      applicationDate: json['applicationDate'] ?? '',
      leaveDate: json['leaveDate'] ?? '',
      duration: json['duration'] ?? '1 DAY',
      reason: json['reason'] ?? '',
      slpAddress: json['slpAddress'],
      status: json['status'] ?? '',
      actionBy: json['actionBy'] ?? '',
      actionRemarks: json['actionRemarks'],
    );
  }

  Map<String, dynamic> toJson() => {
        'slNo': slNo,
        'leaveType': leaveType,
        'applicationDate': applicationDate,
        'leaveDate': leaveDate,
        'duration': duration,
        'reason': reason,
        'slpAddress': slpAddress,
        'status': status,
        'actionBy': actionBy,
        'actionRemarks': actionRemarks,
      };
}

class DashboardData {
  final String lastUpdated;
  final Map<String, String> leaves;
  final List<LapsingAlert> alerts;
  final List<LeaveHistoryItem> leaveHistory;
  final List<CircularItem> vipCirculars;
  final List<CircularItem> fomoCirculars;

  DashboardData({
    required this.lastUpdated,
    required this.leaves,
    required this.alerts,
    this.leaveHistory = const [],
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

    final historyList = <LeaveHistoryItem>[];
    if (json['leave_history'] is List) {
      for (final item in json['leave_history']) {
        if (item is Map<String, dynamic>) {
          historyList.add(LeaveHistoryItem.fromJson(item));
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
      leaveHistory: historyList,
      vipCirculars: vipList,
      fomoCirculars: fomoList,
    );
  }

  Map<String, dynamic> toJson() => {
        'last_updated': lastUpdated,
        'leaves': leaves,
        'alerts': alerts.map((a) => a.toJson()).toList(),
        'leave_history': leaveHistory.map((h) => h.toJson()).toList(),
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
