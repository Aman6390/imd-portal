import 'dart:convert';
import 'package:intl/intl.dart';

class CircularItem {
  final String title;
  final String link;
  final String date;
  final String category; // e.g. 'General', 'Admin', 'Promotion', 'Transfer', 'MACP', 'Training'
  final bool isMyOffice; // true when issued under "Of Your Office only"
  final bool isNew; // true when marked new on MetNet or uploaded within 3 days
  bool isUnavailable;
  String? cachedPath;

  CircularItem({
    required this.title,
    required this.link,
    required this.date,
    this.category = '',
    this.isMyOffice = false,
    this.isNew = false,
    this.isUnavailable = false,
    this.cachedPath,
  });

  factory CircularItem.fromJson(Map<String, dynamic> json) {
    return CircularItem(
      title: json['title'] ?? '',
      link: json['link'] ?? '',
      date: json['date'] ?? '',
      category: json['category'] ?? '',
      isMyOffice: json['isMyOffice'] == true,
      isNew: json['isNew'] == true,
      isUnavailable: json['isUnavailable'] == true,
      cachedPath: json['cachedPath'],
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'link': link,
        'date': date,
        'category': category,
        'isMyOffice': isMyOffice,
        'isNew': isNew,
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
    if (isCancelled) return false;
    final s = status.toLowerCase();
    if (s.contains('pending') || s.trim() == 'applied') return false;
    return s.contains('approved') || s.contains('availed') || s.contains('sanctioned');
  }

  bool get isPending {
    if (isCancelled || isApproved) return false;
    final s = status.toLowerCase().trim();
    return s.contains('pending') || s == 'applied' || s.startsWith('applied');
  }

  String get canonicalLeaveType {
    final t = leaveType.trim().toLowerCase();
    if (t.contains('restricted') || t == 'rh') return 'Restricted Holiday';
    if (t.contains('compensatory') || t.contains('c-off') || t.contains('comp')) {
      return 'Compensatory Off';
    }
    if (t.contains('earned') || t == 'el') return 'Earned Leave';
    if (t.contains('half pay') || t == 'hpl') return 'Half Pay Leave';
    if (t.contains('eh/ch') || t.contains('eh ') || t.contains('holiday availed')) {
      return 'EH/CH Availed';
    }
    return 'Casual Leave';
  }

  static DateTime? parseFlexibleDate(String str) {
    final clean = str.trim();
    if (clean.isEmpty) return null;

    const formats = [
      'dd-MM-yyyy',
      'dd/MM/yyyy',
      'dd.MM.yyyy',
      'dd-MMM-yyyy',
      'd-M-yyyy',
      'd/M/yyyy',
      'yyyy-MM-dd',
    ];
    for (final fmt in formats) {
      try {
        return DateFormat(fmt).parseLoose(clean);
      } catch (_) {}
    }

    final match = RegExp(r'(\d{1,2})[-/. ]([A-Za-z]+|\d{1,2})[-/. ](\d{2,4})').firstMatch(clean);
    if (match != null) {
      final d = int.tryParse(match.group(1)!) ?? 1;
      final mPart = match.group(2)!;
      final yPart = match.group(3)!;
      final y = int.tryParse(yPart.length == 2 ? '20$yPart' : yPart) ?? DateTime.now().year;
      int? m = int.tryParse(mPart);
      if (m == null) {
        const monthMap = {
          'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
          'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
        };
        final mLower = mPart.toLowerCase();
        for (final entry in monthMap.entries) {
          if (mLower.startsWith(entry.key)) {
            m = entry.value;
            break;
          }
        }
      }
      if (m != null && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        try {
          return DateTime(y, m, d);
        } catch (_) {}
      }
    }
    return null;
  }

  /// Expands this LeaveHistoryItem into daily canonical LeaveHistoryItem records
  /// (one item per calendar date) so the Master Leave Ledger stays normalized.
  List<LeaveHistoryItem> expandToDailyRecords() {
    if (!isGenuineLeave) return [];

    final cleanDate = leaveDate.trim();
    final cType = canonicalLeaveType;
    final dateFmt = DateFormat('dd-MM-yyyy');

    final rangeRegex = RegExp(
      r'(\d{1,2}[-/.][A-Za-z0-9]+[-/. ]\d{2,4})\s*(?:to|-)\s*(\d{1,2}[-/.][A-Za-z0-9]+[-/. ]\d{2,4})',
      caseSensitive: false,
    );
    final rangeMatch = rangeRegex.firstMatch(cleanDate);
    if (rangeMatch != null) {
      final startDt = parseFlexibleDate(rangeMatch.group(1)!);
      final endDt = parseFlexibleDate(rangeMatch.group(2)!);
      if (startDt != null && endDt != null && !startDt.isAfter(endDt)) {
        final list = <LeaveHistoryItem>[];
        DateTime curr = startDt;
        while (!curr.isAfter(endDt) && list.length < 31) {
          list.add(LeaveHistoryItem(
            slNo: slNo,
            leaveType: cType,
            applicationDate: applicationDate,
            leaveDate: dateFmt.format(curr),
            duration: '1 DAY',
            reason: reason,
            slpAddress: slpAddress,
            status: status,
            actionBy: actionBy,
            actionRemarks: actionRemarks,
          ));
          curr = curr.add(const Duration(days: 1));
        }
        return list;
      }
    }

    final singleDt = parseFlexibleDate(cleanDate);
    if (singleDt == null) return [];

    final durMatch = RegExp(r'(\d+)').firstMatch(duration.trim());
    final numDays = durMatch != null ? (int.tryParse(durMatch.group(1)!) ?? 1) : 1;
    final clampedDays = (numDays <= 1 || numDays > 31) ? 1 : numDays;

    final list = <LeaveHistoryItem>[];
    for (int i = 0; i < clampedDays; i++) {
      list.add(LeaveHistoryItem(
        slNo: slNo,
        leaveType: cType,
        applicationDate: applicationDate,
        leaveDate: dateFmt.format(singleDt.add(Duration(days: i))),
        duration: clampedDays == 1 ? duration : '1 DAY',
        reason: reason,
        slpAddress: slpAddress,
        status: status,
        actionBy: actionBy,
        actionRemarks: actionRemarks,
      ));
    }
    return list;
  }

  /// Canonical deduplication key for a single-day ledger entry: yyyy-MM-dd|LeaveType
  String get ledgerKey {
    final dt = parseFlexibleDate(leaveDate) ?? parsedLeaveDate;
    final datePart = dt != null ? DateFormat('yyyy-MM-dd').format(dt) : leaveDate.trim();
    return '$datePart|$canonicalLeaveType';
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
  String get elBalance => leaves['Earned Leave (EL)'] ?? '0';
  String get hplBalance => leaves['Half Pay Leave (HPL)'] ?? '0';

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

  DashboardData copyWith({
    String? lastUpdated,
    Map<String, String>? leaves,
    List<LapsingAlert>? alerts,
    List<LeaveHistoryItem>? leaveHistory,
    List<CircularItem>? vipCirculars,
    List<CircularItem>? fomoCirculars,
  }) {
    return DashboardData(
      lastUpdated: lastUpdated ?? this.lastUpdated,
      leaves: leaves ?? this.leaves,
      alerts: alerts ?? this.alerts,
      leaveHistory: leaveHistory ?? this.leaveHistory,
      vipCirculars: vipCirculars ?? this.vipCirculars,
      fomoCirculars: fomoCirculars ?? this.fomoCirculars,
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
