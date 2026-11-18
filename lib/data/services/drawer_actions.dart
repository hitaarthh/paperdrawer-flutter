import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/models/item.dart';

/// OS actions invoked only in response to a user's tap.
class DrawerActions {
  const DrawerActions();

  Future<void> copyText(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  Future<void> shareText(String text, {Rect? origin}) async {
    await SharePlus.instance.share(
      ShareParams(text: text, sharePositionOrigin: origin),
    );
  }

  Future<void> shareFiles(List<XFile> files, {Rect? origin}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: files,
        fileNameOverrides: files.map((file) => file.name).toList(),
        sharePositionOrigin: origin,
      ),
    );
  }

  Future<void> openLink(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw const FormatException('That link couldn’t open.');
    }
  }

  Future<void> openAttachment(Attachment attachment) async {
    final result = await OpenFilex.open(attachment.path);
    if (result.type != ResultType.done) {
      throw const FormatException('This original couldn’t open.');
    }
  }

  Future<Uint8List?> thumbnailBytes(Attachment attachment) async {
    if (attachment.isPdf) return null;
    try {
      return await File(attachment.path).readAsBytes();
    } on FileSystemException {
      return null;
    }
  }
}
