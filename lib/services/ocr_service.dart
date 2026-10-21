import 'dart:io';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'scraper_engine.dart';

/// Service that renders PDF Page 1 and runs Google ML Kit Devanagari (Hindi + English) OCR.
class OcrService {
  static const MethodChannel _pdfChannel = MethodChannel('com.imd.portal/pdf_renderer');

  /// Downloads the circular PDF from [pdfUrl], renders page 1 to an image, and performs local Devanagari OCR.
  /// Returns the extracted text in lowercase for keyword matching.
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

      // Render Page 0 to JPEG via native Android PdfRenderer
      final String? imagePath = await _pdfChannel.invokeMethod<String>(
        'renderFirstPage',
        {'pdfPath': tempPdf.path},
      );

      if (imagePath == null || imagePath.isEmpty) {
        return '';
      }

      // Run on-device Google ML Kit Text Recognition with Devanagari script model
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.devanagiri);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      return recognizedText.text;
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

  /// Runs on-device OCR directly on a local PDF file with Devanagari & Latin fallback
  static Future<String> processLocalPdfFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists() || await file.length() < 100) {
        return '';
      }

      final String? imagePath = await _pdfChannel.invokeMethod<String>(
        'renderFirstPage',
        {'pdfPath': filePath},
      ).timeout(const Duration(seconds: 6), onTimeout: () => null);

      if (imagePath == null || imagePath.isEmpty) {
        return '';
      }

      final inputImage = InputImage.fromFilePath(imagePath);
      String text = '';

      // 1. Attempt Devanagari OCR with a strict 4-second timeout
      try {
        final devanagariRecognizer = TextRecognizer(script: TextRecognitionScript.devanagiri);
        final RecognizedText recognizedText = await devanagariRecognizer
            .processImage(inputImage)
            .timeout(const Duration(seconds: 4));
        await devanagariRecognizer.close();
        text = recognizedText.text;
      } catch (e) {
        print('Devanagari model pending/timeout, falling back to Latin: $e');
      }

      // 2. Fallback: If Devanagari produced nothing or timed out (e.g. model pending download on mobile data),
      // run instant pre-bundled Latin OCR
      if (text.trim().isEmpty) {
        try {
          final latinRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
          final RecognizedText recognizedText = await latinRecognizer
              .processImage(inputImage)
              .timeout(const Duration(seconds: 4));
          await latinRecognizer.close();
          text = recognizedText.text;
        } catch (_) {}
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
