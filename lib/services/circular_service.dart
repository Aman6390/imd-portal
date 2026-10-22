import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../main.dart';
import '../models/dashboard_data.dart';
import 'ai_circular_service.dart';
import 'ocr_service.dart';
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

  /// Fetches verified PDF bytes across candidate URLs and fallback authenticated session
  static Future<List<int>?> _fetchValidPdfBytes(CircularItem item) async {
    final candidateUrls = _generateCandidateUrls(item.link);
    List<int>? validPdfBytes;

    // 1. Probing standard HTTP requests across candidate paths
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

    // 2. Fallback: Authenticated session probe with login session cookies
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
    return validPdfBytes;
  }

  /// Downloads circular PDF to cache silently without launching external viewer
  static Future<CircularStatus> _downloadPdfSilently(CircularItem item, File localFile) async {
    if (item.isUnavailable) return CircularStatus.unavailable;
    if (await localFile.exists() && await localFile.length() > 500) {
      item.cachedPath = localFile.path;
      return CircularStatus.success;
    }

    final bytes = await _fetchValidPdfBytes(item);
    if (bytes == null) {
      item.isUnavailable = true;
      return CircularStatus.unavailable;
    }

    try {
      await localFile.writeAsBytes(bytes, flush: true);
      item.cachedPath = localFile.path;
      item.isUnavailable = false;
      return CircularStatus.success;
    } catch (_) {
      return CircularStatus.error;
    }
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

    final validPdfBytes = await _fetchValidPdfBytes(item);

    // 2. If all candidates failed or returned 404 / HTML error, document was removed
    if (validPdfBytes == null) {
      item.isUnavailable = true;
      return CircularStatus.unavailable;
    }

    // 3. Save verified PDF to local cache and launch via Android FileProvider
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

  /// Clears all downloaded circular PDF documents from cache
  static Future<int> clearDownloadedCache() async {
    int deletedCount = 0;
    try {
      final circularsDir = await _getCircularsDirectory();
      if (await circularsDir.exists()) {
        final files = circularsDir.listSync();
        for (final file in files) {
          if (file is File) {
            try {
              file.deleteSync();
              deletedCount++;
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    return deletedCount;
  }

  /// Automatically purges downloaded circular PDF files older than 30 days to save storage
  static Future<int> purgeFilesOlderThan30Days() async {
    int deletedCount = 0;
    try {
      final circularsDir = await _getCircularsDirectory();
      if (await circularsDir.exists()) {
        final cutoff = DateTime.now().subtract(const Duration(days: 30));
        final files = circularsDir.listSync();
        for (final file in files) {
          if (file is File) {
            try {
              final stat = file.statSync();
              if (stat.modified.isBefore(cutoff)) {
                file.deleteSync();
                deletedCount++;
              }
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    return deletedCount;
  }

  /// Inspects and displays the scanned text recognized by Google ML Kit Devanagari OCR
  static Future<void> inspectCircularOcr(BuildContext context, CircularItem item) async {
    final activeContext = rootNavigatorKey.currentContext ?? context;

    // 1. Instant check: If notice is already confirmed unavailable/withdrawn, show dialog immediately
    if (item.isUnavailable) {
      if (activeContext.mounted) {
        showUnavailableDialog(activeContext, item);
      }
      return;
    }

    bool userCancelled = false;
    bool isProgrammaticDismiss = false;
    final statusNotifier = ValueNotifier<String>('Step 1/2: Checking offline cache...');
    BuildContext? progressDialogContext;

    void dismissProgressDialog() {
      if (progressDialogContext != null && progressDialogContext!.mounted) {
        isProgrammaticDismiss = true;
        try {
          Navigator.of(progressDialogContext!).pop();
        } catch (_) {}
        progressDialogContext = null;
      }
    }

    // Dismissible Progress Dialog
    showDialog(
      context: activeContext,
      barrierDismissible: true,
      builder: (ctx) {
        progressDialogContext = ctx;
        return PopScope(
          canPop: true,
          onPopInvoked: (_) {
            if (!isProgrammaticDismiss) {
              userCancelled = true;
            }
          },
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.document_scanner_rounded, color: Colors.purpleAccent, size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Scanned Notice Text Inspector', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            content: ValueListenableBuilder<String>(
              valueListenable: statusNotifier,
              builder: (_, status, __) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          status,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.title,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  userCancelled = true;
                  dismissProgressDialog();
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );

    final circularsDir = await _getCircularsDirectory();
    final filename = _getLocalFilename(item.link);
    final localFile = File('${circularsDir.path}/$filename');

    // Step 1: Ensure PDF is downloaded locally
    if (!await localFile.exists() || await localFile.length() < 500) {
      statusNotifier.value = 'Step 1/2: Downloading PDF from MetNet...';
      final status = await _downloadPdfSilently(item, localFile);

      if (userCancelled) {
        dismissProgressDialog();
        return;
      }

      if (status == CircularStatus.unavailable) {
        dismissProgressDialog();
        final currentCtx = rootNavigatorKey.currentContext ?? context;
        if (currentCtx.mounted) {
          showUnavailableDialog(currentCtx, item);
        }
        return;
      } else if (status == CircularStatus.error) {
        dismissProgressDialog();
        final currentCtx = rootNavigatorKey.currentContext ?? context;
        if (currentCtx.mounted) {
          ScaffoldMessenger.of(currentCtx).showSnackBar(
            const SnackBar(content: Text('Could not download circular from portal.')),
          );
        }
        return;
      }
    }

    if (userCancelled) {
      dismissProgressDialog();
      return;
    }

    // Step 2: Running ML OCR
    statusNotifier.value = 'Step 2/2: Extracting Hindi & English text (1-2s)...';

    String recognizedText = '';
    try {
      if (await localFile.exists() && await localFile.length() > 500) {
        recognizedText = await OcrService.processLocalPdfFile(localFile.path)
            .timeout(const Duration(seconds: 6), onTimeout: () => '');
      }
    } catch (_) {}

    // Always unconditionally dismiss loading dialog
    dismissProgressDialog();

    if (userCancelled) return;

    // Brief settling pause to ensure previous dialog pop animation settles cleanly
    await Future.delayed(const Duration(milliseconds: 100));

    final resultContext = rootNavigatorKey.currentContext ?? context;
    if (!resultContext.mounted) return;

    final vipKeywords = await StorageService.loadVipKeywords();
    final aiMeta = AiCircularService.getMetadata(item.link, item.title);
    final extraContext = aiMeta != null
        ? '${aiMeta.targetCadre} ${aiMeta.summaryEn}'
        : null;
    final matchedKeywords = StorageService.findMatchedVipKeywords(
      title: item.title,
      ocrText: recognizedText,
      vipKeywords: vipKeywords,
      extraContext: extraContext,
    );

    showDialog(
      context: resultContext,
      barrierDismissible: true,
      builder: (resultCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.document_scanner_rounded, color: Colors.purpleAccent, size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Document Summary (AI Scanner)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                if (matchedKeywords.isNotEmpty) ...[
                  const Text('Matched VIP Keywords:',
                      style: TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: matchedKeywords
                        .map((kw) => Chip(
                              label: Text(kw, style: const TextStyle(fontSize: 11)),
                              backgroundColor: Colors.amber.withOpacity(0.15),
                              side: BorderSide(color: Colors.amber.shade700),
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('Recognized Text Preview (Hindi / English):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 260),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      recognizedText.trim().isNotEmpty
                          ? recognizedText.trim()
                          : 'No text detected on Page 1 (scanned image may be handwritten, low contrast, or blank).',
                      style: const TextStyle(fontSize: 12, height: 1.4, fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (recognizedText.trim().isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy Text'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: recognizedText.trim()));
                ScaffoldMessenger.of(resultCtx).showSnackBar(
                  const SnackBar(
                    content: Text('Extracted text copied to clipboard!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          FilledButton(
            onPressed: () => Navigator.of(resultCtx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
