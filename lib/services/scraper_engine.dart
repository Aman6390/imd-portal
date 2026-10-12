import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/dashboard_data.dart';
import 'rsa_crypto.dart';

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
  static const List<String> vipKeywords = [
    'scientific assistant',
    's.a.',
    'scientist',
    'transfer',
    'posting',
    'promotion',
    'ldce',
    'macp',
    'leave',
    'allowance',
  ];

  static const List<String> junkKeywords = [
    'driver',
    'canteen',
    'cook',
    'mechanic',
    'carpenter',
    'mts',
    'attendant',
    'clerk',
    'steno',
    'stenographer',
    'hindi translator',
    'staff car',
  ];

  /// Parses leave balances and expiring C-Offs from leave_1.php HTML
  static (Map<String, String>, List<LapsingAlert>) parseLeaves(dom.Document soup) {
    final htmlText = soup.body?.text ?? '';

    final clMatch = RegExp(r'Casual Leaves.*?Balance\s*=\s*(\d+)').firstMatch(htmlText);
    final rhMatch = RegExp(r'Restricted Holidays.*?Balance\s*=\s*(\d+)').firstMatch(htmlText);
    final coffMatch = RegExp(r'Compensatory Off.*?Balance\s*=\s*(\d+)').firstMatch(htmlText);

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

  /// Parses circulars and filters into VIP and FOMO categories
  static (List<CircularItem>, List<CircularItem>) parseCirculars(dom.Document soup) {
    final vipCirculars = <CircularItem>[];
    final fomoCirculars = <CircularItem>[];

    final rows = soup.querySelectorAll('tr[bgcolor="#ffffff"], tr[bgcolor="#f5f5f5"]');
    for (final row in rows) {
      final cols = row.querySelectorAll('td');
      if (cols.length >= 4) {
        final aTag = cols[1].querySelector('a');
        if (aTag != null) {
          final title = aTag.text.trim().replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');
          final rawHref = aTag.attributes['href'] ?? '';
          final link = 'https://metnet.imd.gov.in' + rawHref.replaceAll('..', '');
          final uploadDate = cols[3].text.trim();
          final titleLower = title.toLowerCase();

          // Check junk filter
          if (junkKeywords.any((junk) => titleLower.contains(junk))) {
            continue;
          }

          final item = CircularItem(title: title, link: link, date: uploadDate);

          // Check VIP filter
          if (vipKeywords.any((vip) => titleLower.contains(vip))) {
            vipCirculars.add(item);
          } else {
            fomoCirculars.add(item);
          }
        }
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
        String? circularUrl;
        const baseUrl = 'https://metnet.imd.gov.in/phps/';

        for (final a in soupMain.querySelectorAll('a[href]')) {
          final href = a.attributes['href'] ?? '';
          if (href.contains('leave_1.php') && leaveUrl == null) {
            leaveUrl = Uri.parse(baseUrl).resolve(href).toString();
          } else if (href.contains('circulars_display_2.php') &&
              href.contains('GENERAL') &&
              circularUrl == null) {
            circularUrl = Uri.parse(baseUrl).resolve(href).toString();
          }
        }

        if (leaveUrl == null || circularUrl == null) {
          return (false, '❌ Dashboard URLs not found. Please verify your credentials.', null);
        }

        // Step 7: Fetch and parse leave balances
        final leavePage = await session.get(Uri.parse(leaveUrl)).timeout(const Duration(seconds: 25));
        final (leaveBalances, lapsingAlerts) = parseLeaves(html_parser.parse(leavePage.body));

        // Step 8: Fetch and parse circulars
        final circularPage =
            await session.get(Uri.parse(circularUrl)).timeout(const Duration(seconds: 25));
        final (vipCirc, fomoCirc) = parseCirculars(html_parser.parse(circularPage.body));

        final nowFormatted = DateFormat('dd-MM-yyyy HH:mm:ss').format(DateTime.now());

        final data = DashboardData(
          lastUpdated: nowFormatted,
          leaves: leaveBalances,
          alerts: lapsingAlerts,
          vipCirculars: vipCirc.take(10).toList(),
          fomoCirculars: fomoCirc.take(15).toList(),
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
