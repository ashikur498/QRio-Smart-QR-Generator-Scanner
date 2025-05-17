import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as scanner;
import 'package:flutter/services.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QRIO',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  String? qrData;
  final GlobalKey globalKey = GlobalKey();

  Future<void> _saveQrToGallery() async {
    if (qrData == null || qrData!.isEmpty) return;

    var status = await Permission.storage.status;
    if (status.isDenied) {
      status = await Permission.storage.request();
    }
    if (status.isPermanentlyDenied) {
      openAppSettings();
      return;
    }

    if (status.isGranted) {
      try {
        // Wait until the next frame is painted
        await Future.delayed(Duration(milliseconds: 100));
        await WidgetsBinding.instance.endOfFrame;

        RenderRepaintBoundary boundary =
        globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        if (boundary.debugNeedsPaint) {
          await Future.delayed(const Duration(milliseconds: 200));
        }

        ui.Image image = await boundary.toImage(pixelRatio: 3.0);
        ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
        Uint8List pngBytes = byteData!.buffer.asUint8List();

        final result = await ImageGallerySaver.saveImage(
          pngBytes,
          name: "qr_code_${DateTime.now().millisecondsSinceEpoch}",
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['isSuccess'] == true
                ? 'QR Code saved to gallery!'
                : 'Failed to save QR Code.'),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving image: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission denied.')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("QRIO Smart")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Enter text to generate QR code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  qrData = _textController.text.trim();
                });
              },
              child: const Text('Generate QR Code'),
            ),
            const SizedBox(height: 20),
            if (qrData != null && qrData!.isNotEmpty)
              Column(
                children: [
                  RepaintBoundary(
                    key: globalKey,
                    child: QrImageView(
                      data: qrData!,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _saveQrToGallery,
                    child: const Text('Save QR to Gallery'),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const QRScannerScreen()),
                );
              },
              child: const Text("Scan QR Code"),
            ),
          ],
        ),
      ),
    );
  }
}

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  String? result;
  final scanner.MobileScannerController controller =
  scanner.MobileScannerController();

  Future<void> scanImageFromGallery() async {
    final pickedImage =
    await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedImage == null) return;

    final inputImage = InputImage.fromFile(File(pickedImage.path));
    final barcodeScanner = BarcodeScanner();
    final List<Barcode> barcodes =
    await barcodeScanner.processImage(inputImage);

    if (barcodes.isNotEmpty) {
      setState(() {
        result = barcodes.first.rawValue;
      });
    } else {
      setState(() {
        result = 'No QR code found in image';
      });
    }

    await barcodeScanner.close();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void handleDetection(scanner.BarcodeCapture capture) {
    final scanner.Barcode barcode = capture.barcodes.first;
    final String? code = barcode.rawValue;
    if (code != null) {
      controller.stop();
      setState(() {
        result = code;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: scanner.MobileScanner(
              controller: controller,
              onDetect: handleDetection,
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                if (result != null)
                  Text('Result: $result')
                else
                  const Text('Scan a code or pick from gallery'),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: scanImageFromGallery,
                  child: const Text('Scan from Gallery'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
