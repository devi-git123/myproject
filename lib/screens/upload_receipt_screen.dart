import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'add_expense_screen.dart';

const Color kTealColor = Color(0xFF2B90B6);

class UploadReceiptScreen extends StatefulWidget {
  const UploadReceiptScreen({super.key});

  @override
  State<UploadReceiptScreen> createState() => _UploadReceiptScreenState();
}

class _UploadReceiptScreenState extends State<UploadReceiptScreen> {
  File? _image;
  bool _isProcessing = false;
  double? _detectedAmount;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _detectedAmount = null;
      });
      _scanReceipt(_image!);
    }
  }

  Future<void> _scanReceipt(File imageFile) async {
    setState(() => _isProcessing = true);
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      double? maxFound;
      RegExp amountRegExp = RegExp(r'(\d+\.\d{2})');

      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          String text = line.text.replaceAll(',', '').trim();
          if (amountRegExp.hasMatch(text)) {
            final matches = amountRegExp.allMatches(text);
            for (var match in matches) {
              double val = double.parse(match.group(0)!);
              if (maxFound == null || val > maxFound) maxFound = val;
            }
          }
        }
      }
      setState(() => _detectedAmount = maxFound);
    } catch (e) {
      debugPrint("OCR Error: $e");
    } finally {
      textRecognizer.close();
      setState(() => _isProcessing = false);
    }
  }

  Future<String?> _uploadToStorage(File file) async {
    try {
      String fileName = 'receipts/${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Storage Error: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Receipt"), backgroundColor: kTealColor, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              height: 250, width: double.infinity,
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(15)),
              child: _image != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(_image!, fit: BoxFit.cover))
                  : const Icon(Icons.receipt_long, size: 80, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            if (_isProcessing) const CircularProgressIndicator(color: kTealColor),
            if (_detectedAmount != null)
              Text("Detected: LKR ${_detectedAmount!.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: () => _pickImage(ImageSource.camera), child: const Text("Camera"))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(onPressed: () => _pickImage(ImageSource.gallery), child: const Text("Gallery"))),
              ],
            ),
            const SizedBox(height: 30),
            if (_image != null && !_isProcessing)
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  onPressed: () async {
                    setState(() => _isProcessing = true);
                    String? url = await _uploadToStorage(_image!);
                    setState(() => _isProcessing = false);
                    if (mounted) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => AddExpenseScreen(
                          initialAmount: _detectedAmount?.toStringAsFixed(2),
                          receiptUrl: url,
                        ),
                      ));
                    }
                  },
                  child: const Text("Confirm & Continue"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}