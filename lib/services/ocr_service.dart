import 'dart:io';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'scraper_engine.dart';

/// Service that renders PDF Page 1 and runs Google ML Kit Devanagari (Hindi + English) OCR.
class OcrService {
  static const MethodChannel _pdfChannel = MethodChannel('com.imd.portal/pdf_renderer');

  /// Downloads circular PDF from [pdfUrl] and processes with high-speed Latin/Devanagari dual-engine OCR.
  static Future<String> processPdfFromUrl(String pdfUrl, SessionHttpClient session) async {
    File? tempPdf;
    try {
      final cleanUrl = Uri.encodeFull(pdfUrl.trim());
      final uri = Uri.parse(cleanUrl);
      final response = await session.get(uri).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return '';
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      tempPdf = File('${tempDir.path}/circ_$timestamp.pdf');
      await tempPdf.writeAsBytes(response.bodyBytes);

      return await processLocalPdfFile(tempPdf.path);
    } catch (e) {
      print('OCR extraction error for $pdfUrl: $e');
      return '';
    } finally {
      if (tempPdf != null && tempPdf.existsSync()) {
        try {
          tempPdf.deleteSync();
        } catch (_) {}
      }
    }
  }

  /// Runs on-device OCR directly on a local PDF file with Latin & Devanagari dual-engine
  static Future<String> processLocalPdfFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists() || await file.length() < 100) {
        return '';
      }

      final String? imagePath = await _pdfChannel.invokeMethod<String>(
        'renderFirstPage',
        {'pdfPath': filePath},
      ).timeout(const Duration(seconds: 4), onTimeout: () => null);

      if (imagePath == null || imagePath.isEmpty) {
        return '';
      }

      final inputImage = InputImage.fromFilePath(imagePath);
      String text = '';

      // 1. High-speed Latin OCR (Pre-bundled worldwide on Android, 100% offline, completes in ~300ms)
      TextRecognizer? latinRecognizer;
      try {
        latinRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
        final RecognizedText recognizedText = await latinRecognizer
            .processImage(inputImage)
            .timeout(const Duration(seconds: 2));
        text = recognizedText.text;
      } catch (e) {
        print('Latin OCR error: $e');
      } finally {
        try {
          latinRecognizer?.close().timeout(const Duration(milliseconds: 300), onTimeout: () => null);
        } catch (_) {}
      }

      // 2. If no Latin text found (e.g. pure Hindi scanned document), invoke Devanagari OCR
      if (text.trim().isEmpty) {
        TextRecognizer? devanagariRecognizer;
        try {
          devanagariRecognizer = TextRecognizer(script: TextRecognitionScript.devanagiri);
          final RecognizedText recognizedText = await devanagariRecognizer
              .processImage(inputImage)
              .timeout(const Duration(seconds: 2));
          text = recognizedText.text;
        } catch (e) {
          print('Devanagari model pending/timeout: $e');
        } finally {
          try {
            devanagariRecognizer?.close().timeout(const Duration(milliseconds: 300), onTimeout: () => null);
          } catch (_) {}
        }
      }

      // 3. Immediately delete temporary rendered JPEG to prevent storage accumulation
      try {
        final renderedImg = File(imagePath);
        if (await renderedImg.exists()) {
          await renderedImg.delete();
        }
      } catch (_) {}

      return text;
    } catch (e) {
      print('Local OCR processing error: $e');
      return '';
    }
  }
}
