import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRService {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<String?> extractAmount(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

    String fullText = recognizedText.text;

    // Regular expression to find price patterns (e.g., 100.00, 1500.50)
    RegExp regExp = RegExp(r'(\d+\.\d{2})');
    Iterable<RegExpMatch> matches = regExp.allMatches(fullText);

    if (matches.isNotEmpty) {
      // Usually, the largest or the last decimal number in a receipt is the Total Amount
      return matches.last.group(0);
    }
    return null;
  }

  void dispose() {
    _textRecognizer.close();
  }
}