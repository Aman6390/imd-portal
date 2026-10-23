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

  /// Parses leave balances and expiring C-Offs from leave_1.php HTML
  static (Map<String, String>, List<LapsingAlert>) parseLeaves(dom.Document soup) {
    final htmlText = soup.body?.text ?? '';

    final clMatch = RegExp(r'Casual Leaves.*?Balance\s*=\s*(\d+)').firstMatch(htmlText);
    final rhMatch = RegExp(r'Restricted Holidays.*?Balance\s*=\s*(\d+)').firstMatch(htmlText);
    final coffMatch = RegExp(r'Compensatory Off.*?Balance\s*=\s*(\d+)').firstMatch(htmlText);

    // Protective Shield: If none of the 3 balance patterns matched in the HTML,
    // the page is an interstitial prompt (email/password/notice), not the real leave page!
    if (clMatch == null && rhMatch == null && coffMatch == null) {
      return (<String, String>{}, <LapsingAlert>[]);
    }

    final balances = <String, String>{
      'Casual Leave (CL)': clMatch?.group(1) ?? '0',
      'Restricted Holiday (RH)': rhMatch?.group(1) ?? '0',
      'Compensatory Off (C-Off)': coffMatch?.group(1) ?? '0',
    };

    final lapsingAlerts = <LapsingAlert>[];
    final currentDate = DateTime.now();

    final rows = soup.querySelectorAll('tr[bgcolor="#ffffff"], tr[bgcolor="#f5f5f5"]');
    final dateFormat = DateFormat('dd-MM-yyyy');

    for (final row in rows) {
      final cols = row.querySelectorAll('td');
      if (cols.length >= 10) {
        final dateOfCreditStr = cols[1].text.trim();
        final status = cols[8].text.trim();

        if (status.isEmpty && RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(dateOfCreditStr)) {
          try {
            final creditDate = dateFormat.parse(dateOfCreditStr);
            // In Python: credit_date + relativedelta(months=+6)
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

    return (balances, lapsingAlerts);
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

  /// Parses circulars of the last one month using Title Pre-Filter (Fast-Path), OCR Cache, and on-device Devanagari OCR (Slow-Path)
  static Future<(List<CircularItem>, List<CircularItem>)> parseCirculars(
    dom.Document soup,
    SessionHttpClient session, {
    String sourceBaseUrl = 'https://metnet.imd.gov.in/phps/circulars_display_2.php',
    int maxUncachedOcr = 15,
  }) async {
    final vipCirculars = <CircularItem>[];
    final fomoCirculars = <CircularItem>[];

    final dynamicVipKeywords = await StorageService.loadVipKeywords();
    final dynamicJunkKeywords = await StorageService.loadJunkKeywords();
    final ocrCache = await StorageService.loadOcrCache();

    // Calculate cutoff date: exactly 1 month (31 days) ago
    final oneMonthAgo = DateTime.now().subtract(const Duration(days: 31));

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

      // Filter by Date: only keep circulars from the last one month
      if (parsedDate != null) {
        if (parsedDate.isBefore(oneMonthAgo)) {
          // Circular is older than 31 days -> skip
          continue;
        }
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

      final item = CircularItem(title: title, link: link, date: uploadDate);

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
          try {
            final extractedText = await OcrService.processPdfFromUrl(link, session);
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
        final mainPage = await session.get(mainUri).timeout(const Duration(seconds: 25));

        if (mainPage.statusCode != 200) {
          throw HttpException('Main page returned HTTP ${mainPage.statusCode}');
        }

        final soupMain = html_parser.parse(mainPage.body);
        String? leaveUrl;
        const baseUrl = 'https://metnet.imd.gov.in/phps/';

        // Multi-category circular URL discovery across the portal
        final circularTargetUrls = <String>{};

        for (final a in soupMain.querySelectorAll('a[href]')) {
          final href = a.attributes['href'] ?? '';
          final hrefLower = href.toLowerCase();
          final textLower = a.text.toLowerCase();

          if (href.contains('leave_1.php') && leaveUrl == null) {
            leaveUrl = Uri.parse(baseUrl).resolve(href).toString();
          }

          if (hrefLower.contains('circular') ||
              hrefLower.contains('order') ||
              textLower.contains('circular') ||
              textLower.contains('order') ||
              textLower.contains('peripat') ||
              textLower.contains('aadesh') ||
              textLower.contains('परिपत्र') ||
              textLower.contains('आदेश')) {
            if (hrefLower.contains('.php') &&
                !hrefLower.contains('leave') &&
                !hrefLower.contains('logout')) {
              final fullUrl = Uri.parse(baseUrl).resolve(href).toString();
              circularTargetUrls.add(fullUrl);
            }
          }
        }

        // Always query standard MetNet circular sections so no transfers, establishment,
        // or general office orders are missed
        const standardCategories = [
          'https://metnet.imd.gov.in/phps/circulars_display_2.php?type=GENERAL',
          'https://metnet.imd.gov.in/phps/circulars_display_2.php?type=ESTABLISHMENT',
          'https://metnet.imd.gov.in/phps/circulars_display_2.php?type=OFFICE_ORDER',
          'https://metnet.imd.gov.in/phps/circulars_display_2.php?type=TRANSFER',
          'https://metnet.imd.gov.in/phps/circulars_display_2.php',
        ];
        circularTargetUrls.addAll(standardCategories);

        // Fallback for leave URL if not found dynamically
        leaveUrl ??= 'https://metnet.imd.gov.in/phps/leave_1.php';

        // Step 7: Fetch and parse leave balances
        final leavePage = await session.get(Uri.parse(leaveUrl)).timeout(const Duration(seconds: 25));
        final (leaveBalances, lapsingAlerts) = parseLeaves(html_parser.parse(leavePage.body));

        final combinedBody = '${mainPage.body.toLowerCase()} ${leavePage.body.toLowerCase()}';

        final isPasswordChange = combinedBody.contains('change password') ||
            combinedBody.contains('change_password') ||
            combinedBody.contains('password expired') ||
            combinedBody.contains('expired password') ||
            combinedBody.contains('chgpass') ||
            combinedBody.contains('पासवर्ड बदलें') ||
            combinedBody.contains('नया पासवर्ड');

        final isEmailPrompt = combinedBody.contains('unread mail') ||
            combinedBody.contains('unread email') ||
            combinedBody.contains('new mail') ||
            combinedBody.contains('new email') ||
            combinedBody.contains('zimbra') ||
            combinedBody.contains('webmail') ||
            combinedBody.contains('mail.gov.in') ||
            combinedBody.contains('inbox') ||
            combinedBody.contains('ईमेल') ||
            combinedBody.contains('डाक');

        if (isPasswordChange) {
          session.close();
          return (
            false,
            '🔑 MetNet requires a Password Change. Please update your password on MetNet.',
            null,
          );
        }

        if (isEmailPrompt) {
          session.close();
          return (
            false,
            '📬 MetNet Prompt: You have unread official emails blocking portal access.',
            null,
          );
        }

        // Protective Zero-Shield: If leave balances could not be parsed,
        // it means MetNet showed an interstitial notice or mandatory declaration.
        if (leaveBalances.isEmpty) {
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

        final nowFormatted = DateFormat('dd-MM-yyyy HH:mm:ss').format(DateTime.now());

        final data = DashboardData(
          lastUpdated: nowFormatted,
          leaves: leaveBalances,
          alerts: lapsingAlerts,
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
