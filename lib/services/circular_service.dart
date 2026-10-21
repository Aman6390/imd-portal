import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/dashboard_data.dart';
import 'rsa_crypto.dart';
import 'scraper_engine.dart';
import 'storage_service.dart';

enum CircularStatus {
  success,
  unavailable,
  error,
}

class CircularService {
  static const MethodChannel _pdfChannel = MethodChannel('com.imd.portal/pdf_renderer');

  /// Gets the dedicated local directory for storing downloaded circular PDFs
  static Future<Directory> _getCircularsDirectory() async {
    Directory baseDir;
    try {
      final extDirs = await getExternalCacheDirectories();
      if (extDirs != null && extDirs.isNotEmpty) {
        baseDir = extDirs.first;
      } else {
        baseDir = await getTemporaryDirectory();
      }
    } catch (_) {
      baseDir = await getTemporaryDirectory();
    }

    final circularDir = Directory('${baseDir.path}/circulars');
    if (!await circularDir.exists()) {
      await circularDir.create(recursive: true);
    }
    return circularDir;
  }

  /// Generates a safe, repeatable filename for saving the circular locally
  static String _getLocalFilename(String link) {
    final clean = link.trim();
    final uri = Uri.tryParse(clean);
    String originalName = '';
    if (uri != null && uri.pathSegments.isNotEmpty) {
      originalName = uri.pathSegments.last;
      originalName = originalName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    }
    if (originalName.isEmpty || !originalName.toLowerCase().endsWith('.pdf')) {
      originalName = 'circular_${clean.hashCode.abs()}.pdf';
    }
    return originalName;
  }

  /// Generates intelligent sibling URL candidates on MetNet to handle path mismatches
  static List<String> _generateCandidateUrls(String originalUrl) {
    final candidates = <String>[];
    final clean = originalUrl.trim();
    if (clean.isEmpty) return candidates;

    candidates.add(clean);

    final uri = Uri.tryParse(clean);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final filename = uri.pathSegments.last;

      // Candidate 2: standard root docs
      candidates.add('https://metnet.imd.gov.in/docs/$filename');

      // Candidate 3: phps/docs directory
      candidates.add('https://metnet.imd.gov.in/phps/docs/$filename');

      // Candidate 4: Welcome_to_Intra-IMD docs
      candidates.add('https://metnet.imd.gov.in/Welcome_to_Intra-IMD/docs/$filename');

      // Decoded variant (handles potential double-encoded %20 or special characters)
      try {
        final decoded = Uri.decodeFull(clean);
        if (decoded != clean) {
          candidates.add(decoded);
        }
      } catch (_) {}
    }

    return candidates.toSet().toList();
  }

  /// Validates whether the returned bytes represent a genuine PDF (%PDF magic header)
  static bool _isValidPdf(List<int> bytes) {
    if (bytes.length < 100) return false;
    // Magic bytes for PDF: '%PDF' -> 0x25, 0x50, 0x44, 0x46
    return bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46;
  }

  /// Downloads and opens the circular PDF locally with pre-flight checks and fallback routing
  static Future<CircularStatus> openOrDownloadCircular(
    BuildContext context,
    CircularItem item,
  ) async {
    final circularsDir = await _getCircularsDirectory();
    final filename = _getLocalFilename(item.link);
    final localFile = File('${circularsDir.path}/$filename');

    // 1. Check local cache (Never re-download if file already exists)
    if (await localFile.exists() && await localFile.length() > 500) {
      final opened = await _launchLocalPdf(localFile.path);
      if (opened) {
        item.cachedPath = localFile.path;
        return CircularStatus.success;
      }
    }

    final candidateUrls = _generateCandidateUrls(item.link);
    List<int>? validPdfBytes;

    // 2. Probing standard HTTP requests across candidate paths
    for (final testUrl in candidateUrls) {
      try {
        final uri = Uri.parse(Uri.encodeFull(testUrl));
        final response = await http.get(
          uri,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36',
            'Referer': 'https://metnet.imd.gov.in/phps/circulars_display_2.php',
            'Accept': 'application/pdf,application/octet-stream,*/*',
          },
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode == 200 && _isValidPdf(response.bodyBytes)) {
          validPdfBytes = response.bodyBytes;
          break;
        }
      } catch (_) {}
    }

    // 3. Fallback: Authenticated session probe with login session cookies
    if (validPdfBytes == null) {
      final (username, password) = await StorageService.loadCredentials();
      if (username.isNotEmpty && password.isNotEmpty) {
        try {
          final session = SessionHttpClient();
          final loginUri = Uri.parse('https://metnet.imd.gov.in/phps/left1.php');
          final loginPage = await session.get(loginUri).timeout(const Duration(seconds: 15));
          final soupLogin = html_parser.parse(loginPage.body);
          final pubInput = soupLogin.querySelector('input#publicKey');
          final scInput = soupLogin.querySelector('input[name="sc"]');

          if (pubInput != null && scInput != null) {
            final pubKey = pubInput.attributes['value'] ?? '';
            final scVal = scInput.attributes['value'] ?? '';
            if (pubKey.isNotEmpty) {
              final encPass = RsaCrypto.encryptPassword(password, pubKey);
              await session.post(
                Uri.parse('https://metnet.imd.gov.in/phps/emplogin.php'),
                body: {
                  'login_username': username,
                  'password': encPass,
                  'sc': scVal,
                },
              ).timeout(const Duration(seconds: 15));

              for (final testUrl in candidateUrls) {
                try {
                  final resp =
                      await session.get(Uri.parse(testUrl)).timeout(const Duration(seconds: 12));
                  if (resp.statusCode == 200 && _isValidPdf(resp.bodyBytes)) {
                    validPdfBytes = resp.bodyBytes;
                    break;
                  }
                } catch (_) {}
              }
            }
          }
          session.close();
        } catch (_) {}
      }
    }

    // 4. If all candidates failed or returned 404 / HTML error, document was removed
    if (validPdfBytes == null) {
      item.isUnavailable = true;
      return CircularStatus.unavailable;
    }

    // 5. Save verified PDF to local cache and launch via Android FileProvider
    try {
      await localFile.writeAsBytes(validPdfBytes, flush: true);
      item.cachedPath = localFile.path;
      item.isUnavailable = false;

      final opened = await _launchLocalPdf(localFile.path);
      return opened ? CircularStatus.success : CircularStatus.error;
    } catch (_) {
      return CircularStatus.error;
    }
  }

  /// Launches local PDF file using Android FileProvider & native ACTION_VIEW Intent
  static Future<bool> _launchLocalPdf(String filePath) async {
    try {
      final response = await _pdfChannel.invokeMethod<String>(
        'openPdf',
        {'pdfPath': filePath},
      );
      return response == 'SUCCESS';
    } catch (_) {
      return false;
    }
  }

  /// Displays an in-app dialog when a circular has been withdrawn or removed by the department
  static void showUnavailableDialog(BuildContext context, CircularItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Notice Unavailable on Server',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            const Text(
              'This circular was listed on the MetNet portal, but the actual PDF file has been removed or withdrawn from the server by the department (HTTP 404).\n\nThis commonly happens when a notice is canceled or replaced.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            if (item.link.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.link,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (item.link.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy Link'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: item.link));
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Direct link copied to clipboard!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
