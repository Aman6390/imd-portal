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
      final uri = Uri.parse(pdfUrl);
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
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.devanagari);
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
}
