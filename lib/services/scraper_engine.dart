import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/dashboard_data.dart';
import 'ai_circular_service.dart';
import 'ocr_service.dart';
import 'rsa_crypto.dart';
import 'storage_service.dart';
import 'circular_report_service.dart';

/// HTTP Client that automatically maintains session cookies and headers,
/// exactly mimicking Python's `requests.Session()`.
class SessionHttpClient {
  final http.Client _client = http.Client();
  final Map<String, String> _cookies = {};

  final Map<String, String> defaultHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
  };

  void _updateCookies(Map<String, String> headers) {
    final setCookie = headers['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      // Split cookies (handling comma-separated or single)
      final parts = setCookie.split(RegExp(r',(?=\s*[^;=]+=[^;=]+)'));
      for (final cookie in parts) {
        final pair = cookie.split(';').first.trim();
        final equalsIdx = pair.indexOf('=');
        if (equalsIdx != -1) {
          final name = pair.substring(0, equalsIdx).trim();
          final value = pair.substring(equalsIdx + 1).trim();
          if (name.isNotEmpty) {
            _cookies[name] = value;
          }
        }
      }
    }
  }

  String _buildCookieHeader() {
    return _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  Future<http.Response> get(Uri url, {Map<String, String>? extraHeaders}) async {
    final headers = Map<String, String>.from(defaultHeaders);
    if (extraHeaders != null) headers.addAll(extraHeaders);
    final cookieHeader = _buildCookieHeader();
    if (cookieHeader.isNotEmpty) {
      headers['Cookie'] = cookieHeader;
    }

    final response = await _client.get(url, headers: headers);
    _updateCookies(response.headers);
    return response;
  }

  Future<http.Response> post(
    Uri url, {
    Map<String, String>? extraHeaders,
    Object? body,
    Encoding? encoding,
  }) async {
    final headers = Map<String, String>.from(defaultHeaders);
    if (extraHeaders != null) headers.addAll(extraHeaders);
    final cookieHeader = _buildCookieHeader();
    if (cookieHeader.isNotEmpty) {
      headers['Cookie'] = cookieHeader;
    }

    final response = await _client.post(url, headers: headers, body: body, encoding: encoding);
    _updateCookies(response.headers);
    return response;
  }

  void close() {
    _client.close();
  }
}

/// The core scraper engine translated directly from Python's scraper_engine.py.
class ScraperEngine {
  static List<String> get vipKeywords => StorageService.defaultVipKeywords;
  static List<String> get junkKeywords => StorageService.defaultJunkKeywords;

  /// Parses leave balances, expiring C-Offs, and past leave history from leave_1.php / leave_eh1.php HTML
  static (Map<String, String>, List<LapsingAlert>, List<LeaveHistoryItem>) parseLeaves(
    dom.Document soup, {
    bool requireBalanceHeaders = true,
  }) {
    final htmlText = soup.body?.text ?? '';

    final clMatch = RegExp(r'Casual Leaves.*?Balance\s*=\s*(\d+)').firstMatch(htmlText);
    final rhMatch = RegExp(r'Restricted Holidays.*?Balance\s*=\s*(\d+)').firstMatch(htmlText);
    final coffMatch = RegExp(r'Compensatory Off.*?Balance\s*=\s*(\d+)').firstMatch(htmlText);

    // Protective Shield: If none of the 3 balance patterns matched in the HTML,
    // the page is an interstitial prompt (email/password/notice), not the real leave page!
    if (requireBalanceHeaders && clMatch == null && rhMatch == null && coffMatch == null) {
      return (<String, String>{}, <LapsingAlert>[], <LeaveHistoryItem>[]);
    }

    final balances = <String, String>{
      'Casual Leave (CL)': clMatch?.group(1) ?? '0',
      'Restricted Holiday (RH)': rhMatch?.group(1) ?? '0',
      'Compensatory Off (C-Off)': coffMatch?.group(1) ?? '0',
    };

    final lapsingAlerts = <LapsingAlert>[];
    final currentDate = DateTime.now();
    final dateFormat = DateFormat('dd-MM-yyyy');

    final rows = soup.querySelectorAll('tr[bgcolor="#ffffff"], tr[bgcolor="#f5f5f5"]');

    // 1. Parse expiring C-Off duty credits from the Duty Credit Ledger
    for (final row in rows) {
      final cols = row.querySelectorAll('td');
      if (cols.length >= 8) {
        final rowText = row.text.toLowerCase();
        // Identify duty credit rows (e.g. night duties, shift duties, weekend duties)
        final isDutyRow = cols.length >= 10 ||
            rowText.contains('duty') ||
            rowText.contains('shift') ||
            rowText.contains('hours');
        if (isDutyRow) {
          final dateOfCreditStr = cols[1].text.trim();
          final statusColIdx = cols.length >= 10 ? 8 : (cols.length >= 9 ? 7 : (cols.length - 2));
          final status = cols[statusColIdx].text.trim();

          // If status is empty, this C-Off duty credit is unavailed (subject to 6-month expiry)
          if (status.isEmpty && RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(dateOfCreditStr)) {
            try {
              final creditDate = dateFormat.parse(dateOfCreditStr);
              // credit_date + 6 months
              final expiryDate = DateTime(
                creditDate.year,
                creditDate.month + 6,
                creditDate.day,
              );
              final daysLeft = expiryDate.difference(currentDate).inDays;

              if (daysLeft > 0) {
                lapsingAlerts.add(
                  LapsingAlert(
                    creditDate: dateOfCreditStr,
                    expiryDate: dateFormat.format(expiryDate),
                    daysLeft: daysLeft,
                  ),
                );
              }
            } catch (_) {
              // Ignore invalid dates
            }
          }
        }
      }
    }

    // 2. Parse past leave history records strictly from genuine Leave Application tables
    // (Casual Leave, Restricted Holiday, Compensatory Off Availed, Earned Leave)
    final historyList = <LeaveHistoryItem>[];
    final tables = soup.querySelectorAll('table');

    for (final table in tables) {
      final trList = table.querySelectorAll('tr');
      if (trList.isEmpty) continue;

      final tableText = table.text.toLowerCase();

      // Crucial: Completely bypass the Duty Credit Ledger!
      // Duty credits represent extra shifts worked, NEVER leaves taken by the employee.
      if (tableText.contains('duty details') ||
          tableText.contains('date of duty') ||
          tableText.contains('duty date') ||
          tableText.contains('reporting time') ||
          tableText.contains('relieving time') ||
          tableText.contains('total hours') ||
          tableText.contains('duty credit')) {
        continue;
      }

      // Dynamically locate the header row and map column indices
      // Handles both 7-column tables (No duration column: Sl#, AppDate, LeaveDate, On account of, Status, Action By, Remarks)
      // and tables with explicit Duration/No. of Days columns.
      int headerRowIndex = -1;
      int slCol = -1;
      int appDateCol = -1;
      int leaveDateCol = -1;
      int durationCol = -1;
      int reasonCol = -1;
      int statusCol = -1;
      int actionByCol = -1;
      int remarksCol = -1;
      List<String> headerCellTexts = const [];

      for (int r = 0; r < trList.length && r < 3; r++) {
        final cells = trList[r].querySelectorAll('th, td');
        final cellTexts = cells.map((c) => c.text.toLowerCase().trim()).toList();

        final hasSl = cellTexts.any((c) => c.contains('sl') || c.contains('#'));
        final hasLeave = cellTexts.any((c) =>
            c.contains('leave date') ||
            c.contains('period') ||
            c.contains('date of leave') ||
            c.contains('comp-off date') ||
            c.contains('comp off date') ||
            c.contains('eh/ch availed date'));
        final hasApp = cellTexts.any((c) =>
            c.contains('application') ||
            c.contains('applied') ||
            c.contains('date of apply'));

        if ((hasLeave || (hasApp && hasSl)) && cells.length >= 4) {
          headerRowIndex = r;
          headerCellTexts = cellTexts;
          for (int c = 0; c < cells.length; c++) {
            final h = cellTexts[c];
            if (h.contains('sl') || h.contains('#')) {
              slCol = c;
            } else if (h.contains('application') || h.contains('applied') || h.contains('date of apply')) {
              appDateCol = c;
            } else if (h.contains('leave date') ||
                h.contains('period') ||
                h.contains('date of leave') ||
                h.contains('comp-off date') ||
                h.contains('comp off date') ||
                h.contains('eh/ch availed date')) {
              leaveDateCol = c;
            } else if (h.contains('duration') || h.contains('no. of days') || h == 'day' || h.contains('days')) {
              durationCol = c;
            } else if (h.contains('on account of') || h.contains('reason') || h.contains('purpose')) {
              reasonCol = c;
            } else if (h.contains('status')) {
              statusCol = c;
            } else if (h.contains('action') || h.contains('sanction') || h.contains('officer')) {
              actionByCol = c;
            } else if (h.contains('remark')) {
              remarksCol = c;
            }
          }
          break;
        }
      }

      // If no valid leave header was found, skip this table
      if (headerRowIndex == -1 || leaveDateCol == -1) continue;

      // Determine leave type: traverse preceding DOM siblings and search nearest heading
      String sectionHeading = '';
      dom.Element? prev = table.previousElementSibling;
      while (prev != null && sectionHeading.isEmpty) {
        final t = prev.text.trim();
        if (RegExp(r'(Casual|Restricted|Compensatory|Earned|Half\s*Pay|EH/CH|RH|C-Off|CL)', caseSensitive: false).hasMatch(t)) {
          sectionHeading = t;
          break;
        }
        prev = prev.previousElementSibling;
      }
      if (sectionHeading.isEmpty && table.parent != null) {
        var p = table.parent?.previousElementSibling;
        while (p != null && sectionHeading.isEmpty) {
          final t = p.text.trim();
          if (RegExp(r'(Casual|Restricted|Compensatory|Earned|Half\s*Pay|EH/CH|RH|C-Off|CL)', caseSensitive: false).hasMatch(t)) {
            sectionHeading = t;
            break;
          }
          p = p.previousElementSibling;
        }
      }
      if (sectionHeading.isEmpty) {
        final tableOuter = table.outerHtml;
        final fullHtml = soup.outerHtml;
        final tablePos = fullHtml.indexOf(tableOuter);
        if (tablePos > 0) {
          final precedingHtml = fullHtml.substring(0, tablePos);
          final lastCl = precedingHtml.lastIndexOf(RegExp(r'Casual\s*Leave', caseSensitive: false));
          final lastRh = precedingHtml.lastIndexOf(RegExp(r'Restricted\s*Holiday', caseSensitive: false));
          final lastCoff = precedingHtml.lastIndexOf(RegExp(r'Compensatory\s*Off', caseSensitive: false));
          final lastEh = precedingHtml.lastIndexOf(RegExp(r'EH/CH\s*Availed', caseSensitive: false));

          int maxIdx = lastCl;
          if (maxIdx >= 0) sectionHeading = 'Casual Leave';
          if (lastRh > maxIdx) {
            maxIdx = lastRh;
            sectionHeading = 'Restricted Holiday';
          }
          if (lastCoff > maxIdx) {
            maxIdx = lastCoff;
            sectionHeading = 'Compensatory Off';
          }
          if (lastEh > maxIdx) {
            maxIdx = lastEh;
            sectionHeading = 'EH/CH Availed';
          }
        }
      }

      String defaultLeaveType = 'Casual Leave';
      final hLower = sectionHeading.toLowerCase();
      if (hLower.contains('eh/ch') || hLower.contains('eh availed')) {
        defaultLeaveType = 'EH/CH Availed';
      } else if (hLower.contains('restricted') || hLower.contains('rh')) {
        defaultLeaveType = 'Restricted Holiday';
      } else if (hLower.contains('compensatory') || hLower.contains('c-off') || hLower.contains('comp')) {
        defaultLeaveType = 'Compensatory Off';
      } else if (hLower.contains('earned') || hLower.contains('el')) {
        defaultLeaveType = 'Earned Leave';
      } else if (hLower.contains('half pay') || hLower.contains('hpl')) {
        defaultLeaveType = 'Half Pay Leave';
      } else if (hLower.contains('casual') || hLower.contains('cl')) {
        defaultLeaveType = 'Casual Leave';
      } else if (leaveDateCol >= 0 && headerCellTexts.length > leaveDateCol) {
        final colHdr = headerCellTexts[leaveDateCol];
        if (colHdr.contains('comp-off') || colHdr.contains('comp off')) {
          defaultLeaveType = 'Compensatory Off';
        } else if (colHdr.contains('eh/ch')) {
          defaultLeaveType = 'EH/CH Availed';
        }
      }

      for (int r = headerRowIndex + 1; r < trList.length; r++) {
        final tr = trList[r];
        final cols = tr.querySelectorAll('td');
        if (cols.length <= leaveDateCol) continue;

        final slText = (slCol >= 0 && slCol < cols.length) ? cols[slCol].text.trim() : '$r';
        final appDate = (appDateCol >= 0 && appDateCol < cols.length) ? cols[appDateCol].text.trim() : '';
        final leaveDate = cols[leaveDateCol].text.trim();

        // A genuine leave application MUST have a real date in leaveDate!
        final hasValidLeaveDate = RegExp(r'\d{1,2}[-/. ]\d{1,2}[-/. ]\d{2,4}').hasMatch(leaveDate) ||
            RegExp(r'\d{1,2}[-/. ][A-Za-z]+[-/. ]\d{2,4}').hasMatch(leaveDate);
        if (!hasValidLeaveDate) continue;

        final slNo = int.tryParse(slText) ?? r;
        final duration = (durationCol >= 0 && durationCol < cols.length)
            ? cols[durationCol].text.replaceAll('\u00A0', ' ').replaceAll('&nbsp;', ' ').trim()
            : '1 DAY';

        // Reason & SLP Address parsing
        String reason = '';
        String? slpAddress;
        if (reasonCol >= 0 && reasonCol < cols.length) {
          final reasonHtml = cols[reasonCol].innerHtml;
          final reasonLines = reasonHtml
              .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
              .replaceAll(RegExp(r'<[^>]*>'), ' ')
              .split('\n')
              .map((l) => l.replaceAll('\u00A0', ' ').replaceAll('&nbsp;', ' ').trim())
              .where((l) => l.isNotEmpty)
              .toList();

          final mainReasons = <String>[];
          for (final line in reasonLines) {
            if (line.toLowerCase().contains('slp add')) {
              final match = RegExp(r'slp\s*add\s*[:-]+\s*(.*)', caseSensitive: false).firstMatch(line);
              if (match != null && match.group(1)!.trim().isNotEmpty) {
                slpAddress = match.group(1)!.trim();
              } else {
                slpAddress = line;
              }
            } else {
              mainReasons.add(line);
            }
          }
          reason = mainReasons.isNotEmpty ? mainReasons.join(' ') : cols[reasonCol].text.trim();
        }

        // Status column
        final status = (statusCol >= 0 && statusCol < cols.length)
            ? cols[statusCol]
                .text
                .replaceAll('\u00A0', ' ')
                .replaceAll('&nbsp;', ' ')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim()
            : 'Approved & Availed';

        // Action By & Approval Remarks
        String actionBy = (actionByCol >= 0 && actionByCol < cols.length)
            ? cols[actionByCol]
                .text
                .replaceAll('\u00A0', ' ')
                .replaceAll('&nbsp;', ' ')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim()
            : 'Sanctioned';
        String? actionRemarks;
        if (remarksCol >= 0 && remarksCol < cols.length) {
          final remText = cols[remarksCol]
              .text
              .replaceAll('\u00A0', ' ')
              .replaceAll('&nbsp;', ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          if (remText.isNotEmpty) {
            actionRemarks = remText;
          }
        }

        // Specific leave type inference per row (e.g. if row mentions RH or C-Off)
        String itemLeaveType = defaultLeaveType;
        final leaveAndReason = '$leaveDate $reason'.toLowerCase();
        // Skip if leaveDate or reason is a duty credit or shift record
        if (leaveAndReason.contains('duty credit') ||
            leaveAndReason.contains('night duty') ||
            leaveAndReason.contains('general shift') ||
            leaveAndReason.contains('shift duty') ||
            leaveAndReason.contains('in lieu of duty')) {
          continue;
        }

        if (leaveAndReason.contains('restricted holiday') ||
            leaveAndReason.contains('rh-') ||
            leaveAndReason.contains('rh -')) {
          itemLeaveType = 'Restricted Holiday';
        } else if (defaultLeaveType == 'Compensatory Off' ||
            leaveAndReason.contains('compensatory off') ||
            leaveAndReason.contains('c-off') ||
            leaveAndReason.contains('comp off')) {
          itemLeaveType = 'Compensatory Off';
        } else if (defaultLeaveType == 'EH/CH Availed') {
          itemLeaveType = 'EH/CH Availed';
        }

        // Prevent duplicate entries
        final isDuplicate = historyList.any((existing) =>
            existing.leaveDate == leaveDate &&
            existing.leaveType == itemLeaveType &&
            existing.slNo == slNo);

        if (!isDuplicate) {
          historyList.add(
            LeaveHistoryItem(
              slNo: slNo,
              leaveType: itemLeaveType,
              applicationDate: appDate,
              leaveDate: leaveDate,
              duration: duration,
              reason: reason,
              slpAddress: slpAddress,
              status: status,
              actionBy: actionBy,
              actionRemarks: actionRemarks,
            ),
          );
        }
      }
    }

    return (balances, lapsingAlerts, historyList);
  }

  /// Parses Earned Leave (EL) & Half-Pay Leave (HPL) balances and yearly availed spells
  /// from options0_imdceass_show.php?field=leave HTML.
  static List<LeaveHistoryItem> parseCeassLeaveRecord(
    dom.Document soup,
    Map<String, String> balances,
  ) {
    final normalizedText = (soup.body?.text ?? '')
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final elMatch = RegExp(
      r'Earned Leave\s*:\s*Balance\s*:\s*(\d+)\s*Days',
      caseSensitive: false,
    ).firstMatch(normalizedText);
    if (elMatch != null) {
      balances['Earned Leave (EL)'] = elMatch.group(1)!;
    }

    final hplMatch = RegExp(
      r'Half Pay Leave\s*:\s*Balance\s*:\s*(\d+)\s*Days',
      caseSensitive: false,
    ).firstMatch(normalizedText);
    if (hplMatch != null) {
      balances['Half Pay Leave (HPL)'] = hplMatch.group(1)!;
    }

    final spells = <LeaveHistoryItem>[];
    final fullHtml = soup.outerHtml;

    for (final table in soup.querySelectorAll('table')) {
      final trs = table.querySelectorAll('tr');
      if (trs.length < 2) continue;

      final hdrCells = trs.first.querySelectorAll('th, td').map((c) => c.text.toLowerCase().trim()).toList();
      if (hdrCells.length > 6) continue; // Ignore outer layout wrapper tables
      final hasSpell = hdrCells.any((c) => c.contains('spell'));
      final hasFrom = hdrCells.any((c) => c == 'from' || c.contains('from'));
      final hasTo = hdrCells.any((c) => c == 'to' || c.contains('to'));
      if (!hasSpell || !hasFrom || !hasTo) continue;

      // Determine whether this sub-table belongs to Earned Leave or Half Pay Leave
      String leaveType = 'Earned Leave';
      final pos = fullHtml.indexOf(table.outerHtml);
      if (pos > 0) {
        final preceding = fullHtml.substring(0, pos);
        final lastEl = preceding.lastIndexOf(RegExp(r'Earned Leave', caseSensitive: false));
        final lastHpl = preceding.lastIndexOf(RegExp(r'Half Pay Leave', caseSensitive: false));
        if (lastHpl > lastEl) {
          leaveType = 'Half Pay Leave';
        }
      }

      for (int i = 1; i < trs.length; i++) {
        final cols = trs[i].querySelectorAll('td');
        if (cols.length < 3) continue;
        final spellStr = cols[0].text.replaceAll('\u00A0', ' ').trim();
        final fromStr = cols[1].text.replaceAll('\u00A0', ' ').trim();
        final toStr = cols[2].text.replaceAll('\u00A0', ' ').trim();
        final daysStr = cols.length >= 4 ? cols[3].text.replaceAll('\u00A0', ' ').trim() : '1';

        final hasValidFrom = RegExp(r'\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}').hasMatch(fromStr);
        if (!hasValidFrom) continue;

        final hasValidTo = RegExp(r'\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}').hasMatch(toStr);
        final dateRange = (hasValidTo && toStr != fromStr) ? '$fromStr to $toStr' : fromStr;
        final slNo = int.tryParse(spellStr) ?? i;

        spells.add(
          LeaveHistoryItem(
            slNo: slNo,
            leaveType: leaveType,
            applicationDate: fromStr,
            leaveDate: dateRange,
            duration: '${daysStr.isNotEmpty ? daysStr : "1"} DAY',
            reason: 'e-Service Book Spell #$slNo',
            status: 'Approved & Availed',
            actionBy: 'IMD CeASS',
          ),
        );
      }
    }

    return spells;
  }

  /// Parses various date formats commonly used in MetNet circulars (e.g. 15-10-2026, 15/10/2026, 15-Oct-2026, 2026-10-15)
  static DateTime? parseCircularDate(String dateStr) {
    final clean = dateStr.trim().replaceAll('\n', ' ');
    if (clean.isEmpty) return null;

    final formats = [
      'dd-MM-yyyy',
      'dd/MM/yyyy',
      'dd.MM.yyyy',
      'd-M-yyyy',
      'd/M/yyyy',
      'd.M.yyyy',
      'dd-MMM-yyyy',
      'dd/MMM/yyyy',
      'dd MMM yyyy',
      'yyyy-MM-dd',
      'yyyy/MM/dd',
    ];

    for (final fmt in formats) {
      try {
        return DateFormat(fmt).parseLoose(clean);
      } catch (_) {}
    }

    // Regex extraction for embedded dd-MM-yyyy or dd-MMM-yyyy
    final match = RegExp(r'(\d{1,2})[-/. ]([A-Za-z]+|\d{1,2})[-/. ](\d{2,4})').firstMatch(clean);
    if (match != null) {
      final day = int.tryParse(match.group(1)!) ?? 1;
      final yearStr = match.group(3)!;
      final year = int.tryParse(yearStr.length == 2 ? '20$yearStr' : yearStr) ?? DateTime.now().year;
      final monthPart = match.group(2)!;
      int? month = int.tryParse(monthPart);
      if (month == null) {
        const monthMap = {
          'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
          'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
        };
        final mLower = monthPart.toLowerCase();
        for (final entry in monthMap.entries) {
          if (mLower.startsWith(entry.key)) {
            month = entry.value;
            break;
          }
        }
      }
      if (month != null && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }

    // Regex extraction for yyyy-MM-dd
    final matchYmd = RegExp(r'(\d{4})[-/. ](\d{1,2})[-/. ](\d{1,2})').firstMatch(clean);
    if (matchYmd != null) {
      final year = int.tryParse(matchYmd.group(1)!) ?? DateTime.now().year;
      final month = int.tryParse(matchYmd.group(2)!) ?? 1;
      final day = int.tryParse(matchYmd.group(3)!) ?? 1;
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }

    return null;
  }

  /// Infers feed category and whether the feed is scoped to the employee's own office
  static (String category, bool isMyOffice) _classifyFeedUrl(String sourceBaseUrl) {
    final uri = Uri.tryParse(sourceBaseUrl);
    final qp = uri?.queryParameters ?? const <String, String>{};
    final pathLower = (uri?.path ?? sourceBaseUrl).toLowerCase();

    final isMyOffice = pathLower.contains('circulars_display_10.php') ||
        (qp.containsKey('id') && (qp['id'] ?? '').isNotEmpty);

    final orderType = (qp['order_type'] ?? '').toLowerCase();
    final circType = (qp['circular_type'] ?? qp['type'] ?? '').toLowerCase();

    String category = '';
    if (orderType == 'orders_pt') {
      category = 'Promotion';
    } else if (orderType == 'orders_ot' || orderType == 'orders_st') {
      category = 'Transfer';
    } else if (orderType == 'orders_macp') {
      category = 'MACP';
    } else if (circType == 'admin') {
      category = 'Admin';
    } else if (circType == 'training') {
      category = 'Training';
    } else if (circType == 'vacancy') {
      category = 'Vacancy';
    } else if (circType == 'rajbhasha') {
      category = 'Rajbhasha';
    } else if (circType == 'seminar' || circType == 'workshop') {
      category = 'Workshop';
    } else if (circType == 'general') {
      category = 'General';
    }

    return (category, isMyOffice);
  }

  /// Parses circulars of the last one month using Title Pre-Filter (Fast-Path), OCR Cache, and on-device Devanagari OCR (Slow-Path)
  static Future<(List<CircularItem>, List<CircularItem>)> parseCirculars(
    dom.Document soup,
    SessionHttpClient session, {
    String sourceBaseUrl = 'https://metnet.imd.gov.in/phps/circulars_display_2.php',
    int maxUncachedOcr = 15,
  }) async {
    final vipCirculars = <CircularItem>[];
    final fomoCirculars = <CircularItem>[];
    final (feedCategory, feedIsMyOffice) = _classifyFeedUrl(sourceBaseUrl);

    final dynamicVipKeywords = await StorageService.loadVipKeywords();
    final dynamicJunkKeywords = await StorageService.loadJunkKeywords();
    final ocrCache = await StorageService.loadOcrCache();

    // Calculate cutoff date: 31 days for All-India feeds, 90 days (min top 5 rows) for My Office
    final cutoffDate = DateTime.now().subtract(Duration(days: feedIsMyOffice ? 90 : 31));

    // Flexible row selector: standard alternating bgcolor first, fallback to any tr with links
    var rows = soup.querySelectorAll('tr[bgcolor="#ffffff"], tr[bgcolor="#f5f5f5"]');
    if (rows.isEmpty) {
      rows = soup
          .querySelectorAll('table tr')
          .where((tr) => tr.querySelector('td a[href]') != null)
          .toList();
    }

    int uncachedOcrCount = 0;
    int rowIndex = 0;
    int consecutiveOldRows = 0;

    for (final row in rows) {
      rowIndex++;
      final cols = row.querySelectorAll('td');
      if (cols.isEmpty) continue;

      // Locate circular link and title anywhere in the row
      final aTag = row.querySelector('a[href]');
      if (aTag == null) continue;

      final rawTitle = aTag.text.trim();
      if (rawTitle.isEmpty) continue;
      final title = rawTitle.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');

      final rawHref = aTag.attributes['href']?.trim() ?? '';
      if (rawHref.isEmpty) continue;

      // RFC-compliant URL resolution: solves broken string concatenations and relative paths
      String link;
      try {
        link = Uri.parse(sourceBaseUrl).resolve(rawHref).toString();
      } catch (_) {
        link = rawHref;
      }

      // Locate date across columns (scanned from right to left)
      String uploadDate = '';
      DateTime? parsedDate;
      for (final col in cols.reversed) {
        final text = col.text.trim();
        final d = parseCircularDate(text);
        if (d != null) {
          parsedDate = d;
          uploadDate = text;
          break;
        }
      }

      if (uploadDate.isEmpty) {
        if (cols.length >= 4) {
          uploadDate = cols[3].text.trim();
        } else if (cols.length >= 2) {
          uploadDate = cols.last.text.trim();
        }
        parsedDate = parseCircularDate(uploadDate);
      }

      final titleLower = title.toLowerCase();

      // Filter by Date: only keep recent circulars (within cutoff, or top 5 for My Office)
      if (parsedDate != null) {
        if (parsedDate.isBefore(cutoffDate) && !(feedIsMyOffice && rowIndex <= 5)) {
          // Tables are newest-first; once 6 consecutive old rows appear, exit early to save CPU
          consecutiveOldRows++;
          if (consecutiveOldRows >= 6) break;
          continue;
        }
        consecutiveOldRows = 0;
      } else if (rowIndex > 50) {
        // Deep table fallback limit
        continue;
      }

      // FAST-PATH: Title & AI Semantic Pre-Filter
      final aiMeta = AiCircularService.getMetadata(link, title);
      final hasSpecificCadre = aiMeta != null &&
          aiMeta.targetCadre.isNotEmpty &&
          aiMeta.targetCadre != 'General / All';
      final cadreLower = hasSpecificCadre ? aiMeta.targetCadre.toLowerCase() : '';
      final summaryLower = aiMeta?.summaryEn.toLowerCase() ?? '';
      final vipReasonsLower =
          aiMeta?.vipReasons.map((r) => r.toLowerCase()).join(' ') ?? '';

      // Context for Junk filter: Title + Specific Cadre + AI Summary
      final junkSearchContext = '$titleLower $cadreLower $summaryLower';

      // 1. FAST-PATH: Junk Pre-Filter (checks Title + AI Cadre + AI Summary)
      if (dynamicJunkKeywords.any((junk) {
        final j = junk.toLowerCase().trim();
        return j.isNotEmpty && junkSearchContext.contains(j);
      })) {
        continue;
      }

      final item = CircularItem(
        title: title,
        link: link,
        date: uploadDate,
        category: feedCategory,
        isMyOffice: feedIsMyOffice,
      );

      // Context for VIP filter: Title + Specific Cadre + AI Summary + VIP Reasons
      final vipSearchContext =
          '$titleLower $cadreLower $summaryLower $vipReasonsLower';

      // 2. FAST-PATH: VIP Pre-Filter (checks Title + AI Cadre + AI Summary + VIP Reasons, or explicit AI VIP flag)
      final matchesVipKeyword = dynamicVipKeywords.any((vip) {
        final v = vip.toLowerCase().trim();
        return v.isNotEmpty && vipSearchContext.contains(v);
      });

      if (matchesVipKeyword) {
        vipCirculars.add(item);
        CircularReportService.reportIfUnindexed(
          title: title,
          url: link,
          date: uploadDate,
          section: 'VIP',
        );
        continue;
      }

      // 3. SLOW-PATH: Title is ambiguous. Check OCR Cache or execute on-device OCR
      if (link.isNotEmpty && link.startsWith('http')) {
        if (ocrCache.containsKey(link)) {
          final isCachedVip = ocrCache[link] ?? false;
          if (isCachedVip) {
            vipCirculars.add(item);
          } else {
            fomoCirculars.add(item);
          }
        } else if (uncachedOcrCount < maxUncachedOcr) {
          uncachedOcrCount++;
          bool isVip = false;
          String extractedText = '';
          try {
            extractedText = await OcrService.processPdfFromUrl(link, session);
            if (extractedText.isNotEmpty) {
              for (final vip in dynamicVipKeywords) {
                if (StorageService.matchesOcrKeyword(extractedText, vip)) {
                  isVip = true;
                  break;
                }
              }
            }
          } catch (_) {}

          await StorageService.saveOcrCacheEntry(link, isVip);
          CircularReportService.reportIfUnindexed(
            title: title,
            url: link,
            date: uploadDate,
            section: isVip ? 'VIP' : 'General',
            extractedText: extractedText,
          );
          ocrCache[link] = isVip;

          if (isVip) {
            vipCirculars.add(item);
          } else {
            fomoCirculars.add(item);
          }
        } else {
          fomoCirculars.add(item);
        }
      } else {
        fomoCirculars.add(item);
      }
    }

    return (vipCirculars, fomoCirculars);
  }

  /// Executes scraping with exponential backoff retry mechanism (up to 3 tries)
  static Future<(bool, String, DashboardData?)> runScraper({
    required String username,
    required String password,
    int maxRetries = 3,
  }) async {
    int attempts = 0;
    int delaySeconds = 2;

    while (attempts < maxRetries) {
      attempts++;
      final session = SessionHttpClient();

      try {
        // Step 1: Initial welcome page visit
        final welcomeUri = Uri.parse('https://metnet.imd.gov.in/Welcome_to_Intra-IMD/welcome.php');
        await session.get(welcomeUri).timeout(const Duration(seconds: 25));

        // Step 2: Fetch login page containing RSA public key & security code
        final loginUri = Uri.parse('https://metnet.imd.gov.in/phps/left1.php');
        final loginPage = await session.get(loginUri).timeout(const Duration(seconds: 25));

        if (loginPage.statusCode != 200) {
          throw HttpException('Login page returned HTTP ${loginPage.statusCode}');
        }

        final soupLogin = html_parser.parse(loginPage.body);
        final pubInput = soupLogin.querySelector('input#publicKey');
        final scInput = soupLogin.querySelector('input[name="sc"]');

        if (pubInput == null || scInput == null) {
          return (false, '❌ Form inputs not found on login page.', null);
        }

        final publicKeyStr = pubInput.attributes['value'] ?? '';
        final scVal = scInput.attributes['value'] ?? '';

        if (publicKeyStr.isEmpty) {
          return (false, '❌ Public key is empty.', null);
        }

        // Step 3: RSA PKCS1_v1_5 Password Encryption
        final encryptedPass = RsaCrypto.encryptPassword(password, publicKeyStr);

        // Step 4: Assemble POST payload
        final payload = <String, String>{};
        final form = soupLogin.querySelector('form');
        if (form != null) {
          for (final el in form.querySelectorAll('input, button, select')) {
            final name = el.attributes['name'];
            if (name != null && name.isNotEmpty) {
              payload[name] = el.attributes['value'] ?? '';
            }
          }
        }

        payload['login_username'] = username;
        payload['password'] = encryptedPass;
        payload['sc'] = scVal;

        // Step 5: Post login request
        final loginPostUri = Uri.parse('https://metnet.imd.gov.in/phps/emplogin.php');
        final loginHeaders = {
          'Referer': 'https://metnet.imd.gov.in/phps/left1.php',
          'Origin': 'https://metnet.imd.gov.in',
          'Content-Type': 'application/x-www-form-urlencoded',
        };

        await session.post(loginPostUri, extraHeaders: loginHeaders, body: payload).timeout(
              const Duration(seconds: 25),
            );

        // Wait 2 seconds (matches Python time.sleep(2))
        await Future.delayed(const Duration(seconds: 2));

        // Step 6: Fetch main dashboard page
        final mainUri = Uri.parse('https://metnet.imd.gov.in/phps/main2.php?ver=e');
        var mainPage = await session.get(mainUri).timeout(const Duration(seconds: 25));

        if (mainPage.statusCode != 200) {
          throw HttpException('Main page returned HTTP ${mainPage.statusCode}');
        }

        var soupMain = html_parser.parse(mainPage.body);

        // --- SMART "SKIP NOW" INTERSTITIAL BYPASS ---
        // If MetNet presents a password policy warning with an active "SKIP NOW" button,
        // extract the skip URL (including its dynamic session token) and bypass the interstitial!
        dom.Element? skipInput;
        for (final el in soupMain.querySelectorAll('input, button')) {
          final name = (el.attributes['name'] ?? '').toLowerCase();
          final title = (el.attributes['title'] ?? '').toLowerCase();
          final val = (el.attributes['value'] ?? '').toLowerCase();
          if (name == 'skip' || title.contains('skip') || val.contains('skip')) {
            skipInput = el;
            break;
          }
        }
        String? skipUrlStr;

        if (skipInput != null) {
          final onClick = skipInput.attributes['onclick'] ?? '';
          final match = RegExp(r'''window\.location\s*=\s*['"](.*?)['"]''', caseSensitive: false).firstMatch(onClick);
          if (match != null) {
            skipUrlStr = match.group(1);
          }
        }

        // Fallback regex scan across the HTML in case DOM parsing missed it
        if (skipUrlStr == null) {
          final match = RegExp(r'''onclick=["']window\.location\s*=\s*['"](main2\.php\?[^'"]*sc=[^'"]*)['"]''', caseSensitive: false)
              .firstMatch(mainPage.body);
          if (match != null) {
            skipUrlStr = match.group(1);
          }
        }

        if (skipUrlStr != null) {
          final resolvedSkipPath = skipUrlStr.replaceAll('&amp;', '&');
          final skipUri = Uri.parse('https://metnet.imd.gov.in/phps/').resolve(resolvedSkipPath);
          mainPage = await session.get(skipUri).timeout(const Duration(seconds: 25));
          soupMain = html_parser.parse(mainPage.body);
        }
        String? leaveUrl;
        String? leaveMenuUrl;
        String? ehUrl;
        String? ceassLeaveUrl;
        const baseUrl = 'https://metnet.imd.gov.in/phps/';

        // Deduplicated feed queues: My Office first so isMyOffice=true wins deduplication
        final myOfficeFeedMap = <String, String>{};
        final orderFeedMap = <String, String>{};
        final circularFeedMap = <String, String>{};

        String feedKey(Uri u) {
          final qp = u.queryParameters;
          final cType = qp['circular_type'] ?? qp['type'] ?? '';
          final oType = qp['order_type'] ?? '';
          final id = qp['id'] ?? '';
          return '${u.path}|$cType|$oType|$id';
        }

        for (final a in soupMain.querySelectorAll('a[href]')) {
          final href = (a.attributes['href'] ?? '').trim();
          final hrefLower = href.toLowerCase();
          final anchorText = a.text.trim();

          if (href.contains('leave_1.php') && leaveUrl == null) {
            leaveUrl = Uri.parse(baseUrl).resolve(href).toString();
          }
          if (href.contains('leave_0.php') && leaveMenuUrl == null) {
            leaveMenuUrl = Uri.parse(baseUrl).resolve(href).toString();
          }
          if (href.contains('leave_eh1.php') && ehUrl == null) {
            ehUrl = Uri.parse(baseUrl).resolve(href).toString();
          }
          if (href.contains('options0_imdceass_show.php') &&
              href.contains('field=leave') &&
              ceassLeaveUrl == null) {
            ceassLeaveUrl = Uri.parse(baseUrl).resolve(href).toString();
          }

          if (!hrefLower.contains('.php') ||
              hrefLower.contains('leave') ||
              hrefLower.contains('logout')) {
            continue;
          }

          if (hrefLower.contains('circulars_display_10.php') ||
              hrefLower.contains('circulars_display_2.php') ||
              hrefLower.contains('orders_display_2.php')) {
            // Skip zero-count office-only badges (e.g. "0" under My Office or empty SEMINAR/VACANCY=0)
            if (anchorText == '0') continue;

            final fullUrl = Uri.parse(baseUrl).resolve(href.replaceAll('&amp;', '&')).toString();
            final uri = Uri.tryParse(fullUrl);
            if (uri == null) continue;
            final key = feedKey(uri);
            final hasTokenV = (uri.queryParameters['v'] ?? '').isNotEmpty;

            if (hrefLower.contains('circulars_display_10.php') ||
                (uri.queryParameters['id'] ?? '').isNotEmpty) {
              if (!myOfficeFeedMap.containsKey(key) || hasTokenV) {
                myOfficeFeedMap[key] = fullUrl;
              }
            } else if (hrefLower.contains('orders_display_2.php')) {
              if (!orderFeedMap.containsKey(key) || hasTokenV) {
                orderFeedMap[key] = fullUrl;
              }
            } else {
              if (!circularFeedMap.containsKey(key) || hasTokenV) {
                circularFeedMap[key] = fullUrl;
              }
            }
          }
        }

        // If leaveUrl was not found in soupMain, inspect embedded iframes (e.g. left1.php, main1.php)
        if (leaveUrl == null) {
          for (final iframe in soupMain.querySelectorAll('iframe[src]')) {
            final src = iframe.attributes['src'] ?? '';
            if (src.isNotEmpty) {
              try {
                final frameUri = Uri.parse(baseUrl).resolve(src.replaceAll('&amp;', '&'));
                final framePage = await session.get(frameUri).timeout(const Duration(seconds: 15));
                if (framePage.statusCode == 200) {
                  final soupFrame = html_parser.parse(framePage.body);
                  for (final a in soupFrame.querySelectorAll('a[href]')) {
                    final href = a.attributes['href'] ?? '';
                    if (href.contains('leave_1.php') && leaveUrl == null) {
                      leaveUrl = Uri.parse(baseUrl).resolve(href).toString();
                      break;
                    }
                  }
                }
              } catch (_) {}
            }
            if (leaveUrl != null) break;
          }
        }

        // Direct query to left1.php sidebar where leave links reside
        if (leaveUrl == null) {
          try {
            final leftPage = await session.get(Uri.parse('https://metnet.imd.gov.in/phps/left1.php')).timeout(const Duration(seconds: 10));
            if (leftPage.statusCode == 200) {
              final soupLeft = html_parser.parse(leftPage.body);
              for (final a in soupLeft.querySelectorAll('a[href]')) {
                final href = a.attributes['href'] ?? '';
                if (href.contains('leave_1.php')) {
                  leaveUrl = Uri.parse(baseUrl).resolve(href).toString();
                  break;
                }
              }
            }
          } catch (_) {}
        }

        // Ordered feed list: My Office -> Promotions/Transfers/MACP Orders -> All-India Circulars
        final circularTargetUrls = <String>[
          ...myOfficeFeedMap.values,
          ...orderFeedMap.values,
          ...circularFeedMap.values,
        ];

        // Fallback standard MetNet sections if main2.php discovery was empty
        if (circularTargetUrls.isEmpty) {
          circularTargetUrls.addAll(const [
            'https://metnet.imd.gov.in/phps/orders_display_2.php?order_type=orders_pt',
            'https://metnet.imd.gov.in/phps/orders_display_2.php?order_type=orders_ot',
            'https://metnet.imd.gov.in/phps/orders_display_2.php?order_type=orders_st',
            'https://metnet.imd.gov.in/phps/orders_display_2.php?order_type=orders_macp',
            'https://metnet.imd.gov.in/phps/circulars_display_2.php?circular_type=GENERAL',
            'https://metnet.imd.gov.in/phps/circulars_display_2.php?circular_type=ADMIN',
            'https://metnet.imd.gov.in/phps/circulars_display_2.php?circular_type=TRAINING',
            'https://metnet.imd.gov.in/phps/circulars_display_2.php?circular_type=VACANCY',
          ]);
        }

        // Fallback for leave URL if not found dynamically
        leaveUrl ??= 'https://metnet.imd.gov.in/phps/leave_1.php';

        // Step 7: Fetch and parse leave balances
        final leavePage = await session.get(Uri.parse(leaveUrl)).timeout(const Duration(seconds: 25));
        final (leaveBalances, lapsingAlerts, rawLeaveHistory) = parseLeaves(html_parser.parse(leavePage.body));

        // Protective Zero-Shield: If leave balances could not be parsed,
        // determine the exact interstitial barrier (Password Change vs Unread Emails vs Notice)
        if (leaveBalances.isEmpty) {
          final combinedBody = '${mainPage.body.toLowerCase()} ${leavePage.body.toLowerCase()}';

          final isPasswordChange = combinedBody.contains('change password') ||
              combinedBody.contains('change_password') ||
              combinedBody.contains('password expired') ||
              combinedBody.contains('expired password') ||
              combinedBody.contains('chgpass') ||
              combinedBody.contains('password policy') ||
              combinedBody.contains('पासवर्ड बदलें') ||
              combinedBody.contains('नया पासवर्ड');

          if (isPasswordChange) {
            session.close();
            return (
              false,
              '🔑 MetNet requires a Password Change. Please update your password on MetNet.',
              null,
            );
          }

          final isEmailPrompt = combinedBody.contains('unread mail') ||
              combinedBody.contains('unread email') ||
              combinedBody.contains('unread message') ||
              combinedBody.contains('you have unread') ||
              combinedBody.contains('new mail') ||
              combinedBody.contains('new email') ||
              combinedBody.contains('अपठित ईमेल') ||
              combinedBody.contains('नए संदेश');

          if (isEmailPrompt) {
            session.close();
            return (
              false,
              '📬 MetNet Prompt: You have unread official emails blocking portal access.',
              null,
            );
          }

          session.close();
          return (
            false,
            '⚠️ MetNet Notice or Action Required',
            null,
          );
        }

        // Step 8: Multi-Category Circular Scraping & Deduplication
        final allVipCirculars = <CircularItem>[];
        final allFomoCirculars = <CircularItem>[];
        final seenKeys = <String>{};

        for (final cUrl in circularTargetUrls) {
          try {
            final circularPage =
                await session.get(Uri.parse(cUrl)).timeout(const Duration(seconds: 15));
            if (circularPage.statusCode == 200 && circularPage.body.isNotEmpty) {
              final (vipCirc, fomoCirc) = await parseCirculars(
                html_parser.parse(circularPage.body),
                session,
                sourceBaseUrl: cUrl,
                maxUncachedOcr: 5,
              );

              for (final c in vipCirc) {
                final key = '${c.title.trim().toLowerCase()}_${c.link.trim()}';
                if (!seenKeys.contains(key)) {
                  seenKeys.add(key);
                  allVipCirculars.add(c);
                }
              }

              for (final c in fomoCirc) {
                final key = '${c.title.trim().toLowerCase()}_${c.link.trim()}';
                if (!seenKeys.contains(key)) {
                  seenKeys.add(key);
                  allFomoCirculars.add(c);
                }
              }
            }
          } catch (_) {
            // Category query failed or timed out; continue gracefully to next category
          }
        }

        // Sort circulars in descending order (newest uploaded first)
        int circularDateComparator(CircularItem a, CircularItem b) {
          final da = parseCircularDate(a.date);
          final db = parseCircularDate(b.date);
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return db.compareTo(da);
        }

        allVipCirculars.sort(circularDateComparator);
        allFomoCirculars.sort(circularDateComparator);

        // Step 7b: Also fetch EH/CH Availed Register (leave_eh1.php) and e-Service Book Leaves' Record
        // (options0_imdceass_show.php?field=leave for EL/HPL balances & availed spells), then revise Master Leave Ledger
        final combinedRawLeaves = <LeaveHistoryItem>[...rawLeaveHistory];
        if (ceassLeaveUrl != null) {
          try {
            final ceassPage = await session.get(Uri.parse(ceassLeaveUrl)).timeout(const Duration(seconds: 20));
            if (ceassPage.statusCode == 200 && ceassPage.body.isNotEmpty) {
              final elHplSpells = parseCeassLeaveRecord(
                html_parser.parse(ceassPage.body),
                leaveBalances,
              );
              combinedRawLeaves.addAll(elHplSpells);
            }
          } catch (_) {
            // Optional e-Service Book EL/HPL record failed; continue cleanly
          }
        }
        if (ehUrl == null && leaveMenuUrl != null) {
          try {
            final leaveMenuPage = await session.get(Uri.parse(leaveMenuUrl)).timeout(const Duration(seconds: 12));
            if (leaveMenuPage.statusCode == 200) {
              final soupMenu = html_parser.parse(leaveMenuPage.body);
              for (final a in soupMenu.querySelectorAll('a[href]')) {
                final href = a.attributes['href'] ?? '';
                if (href.contains('leave_eh1.php')) {
                  ehUrl = Uri.parse(baseUrl).resolve(href).toString();
                  break;
                }
              }
            }
          } catch (_) {}
        }
        if (ehUrl != null) {
          try {
            final ehPage = await session.get(Uri.parse(ehUrl)).timeout(const Duration(seconds: 15));
            if (ehPage.statusCode == 200 && ehPage.body.isNotEmpty) {
              final (_, _, ehHistory) = parseLeaves(
                html_parser.parse(ehPage.body),
                requireBalanceHeaders: false,
              );
              combinedRawLeaves.addAll(ehHistory);
            }
          } catch (_) {
            // Optional supplementary EH/CH register failed; continue cleanly
          }
        }
        final masterLeaveHistory = await StorageService.reviseMasterLeaveLedger(combinedRawLeaves);

        final nowFormatted = DateFormat('dd-MM-yyyy HH:mm:ss').format(DateTime.now());

        final data = DashboardData(
          lastUpdated: nowFormatted,
          leaves: leaveBalances,
          alerts: lapsingAlerts,
          leaveHistory: masterLeaveHistory,
          vipCirculars: allVipCirculars,
          fomoCirculars: allFomoCirculars,
        );

        session.close();
        return (true, '✅ SUCCESS! Data synced successfully.', data);
      } catch (e) {
        session.close();
        if (attempts >= maxRetries) {
          return (false, 'Error syncing after $maxRetries attempts: $e', null);
        }
        // Exponential backoff delay
        await Future.delayed(Duration(seconds: delaySeconds));
        delaySeconds *= 2;
      }
    }

    return (false, 'Error syncing: maximum retries reached.', null);
  }
}
