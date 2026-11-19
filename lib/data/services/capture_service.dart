import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/models/item.dart';
import 'file_store.dart' show maxAttachmentBytes;

const _acceptedFiles = XTypeGroup(
  label: 'Photos and PDFs',
  extensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic', 'heif', 'webp'],
  mimeTypes: [
    'application/pdf',
    'image/jpeg',
    'image/png',
    'image/heic',
    'image/heif',
    'image/webp',
  ],
  uniformTypeIdentifiers: [
    'com.adobe.pdf',
    'public.jpeg',
    'public.png',
    'public.heic',
    'public.heif',
    'org.webmproject.webp',
  ],
);

/// On-device picker and camera access for the add flow.
class CaptureService {
  const CaptureService();

  Future<CaptureOriginal> inspect(PendingFile original) async {
    try {
      final source = File(original.path);
      final size = await source.length();
      final preview = original.isPdf || size > maxAttachmentBytes
          ? null
          : await source.readAsBytes();
      return CaptureOriginal(size: size, preview: preview);
    } on FileSystemException {
      return const CaptureOriginal();
    }
  }

  Future<List<PendingFile>> pickFiles() async {
    final files = await openFiles(acceptedTypeGroups: const [_acceptedFiles]);
    return files
        .map((file) => PendingFile(path: file.path, name: file.name))
        .toList();
  }

  Future<List<PendingFile>> pickPhotos() async {
    final files = await ImagePicker().pickMultiImage(
      requestFullMetadata: false,
    );
    return files
        .map((file) => PendingFile(path: file.path, name: file.name))
        .toList();
  }

  Future<PendingFile?> pickLedgerPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    return file == null ? null : PendingFile(path: file.path, name: file.name);
  }

  Future<CaptureSession> openCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw const FormatException(
        'There’s no camera available on this device.',
      );
    }
    final camera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await controller.initialize();
    } on CameraException catch (error) {
      await controller.dispose();
      throw FormatException(switch (error.code) {
        'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' => 'To scan a document, allow camera access for Paper Drawer in Settings.',
        'CameraAccessRestricted' =>
          'Camera access is restricted on this device.',
        _ => 'The camera couldn’t open. Try again or choose a photo or PDF.',
      });
    } catch (_) {
      await controller.dispose();
      rethrow;
    }
    return _CameraSession(controller);
  }
}

class CaptureOriginal {
  const CaptureOriginal({this.size, this.preview});

  final int? size;
  final Uint8List? preview;
}

/// The preview and shutter share one camera resource, owned by the screen.
abstract interface class CaptureSession {
  Widget buildPreview();
  Future<PendingFile> takePicture();
  Future<void> setTorch(bool enabled);
  Future<void> close();
}

class _CameraSession implements CaptureSession {
  const _CameraSession(this._controller);

  final CameraController _controller;

  @override
  Widget buildPreview() => CameraPreview(_controller);

  @override
  Future<PendingFile> takePicture() async {
    final file = await _controller.takePicture();
    return PendingFile(path: file.path, name: file.name);
  }

  @override
  Future<void> setTorch(bool enabled) =>
      _controller.setFlashMode(enabled ? FlashMode.torch : FlashMode.off);

  @override
  Future<void> close() => _controller.dispose();
}
