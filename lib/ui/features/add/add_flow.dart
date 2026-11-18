import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/item_repository.dart';
import '../../../data/services/capture_service.dart';
import '../../../domain/models/item.dart';
import '../../../routing/router.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/limit_notice.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/snackbar.dart';
import 'add_details_args.dart';

enum _AddOption { camera, upload, manual }

enum _UploadSource { photos, files }

enum _LimitAction { review, waitlist }

abstract final class AddFlow {
  static Future<void> start(BuildContext context) async {
    if (await _showLimitIfNeeded(context) || !context.mounted) return;
    final option = await showPdSheet<_AddOption>(
      context,
      title: 'Add to your drawer',
      subtitle: 'Keep the original and the dates together.',
      options: const [
        PdSheetOption(
          icon: null,
          glyph: PdGlyph.scan,
          title: 'Scan with camera',
          description: 'Take a photo and read the details.',
          value: _AddOption.camera,
          recommended: true,
        ),
        PdSheetOption(
          icon: LucideIcons.fileUp,
          title: 'Upload a photo or PDF',
          description: 'Choose an original you already have.',
          value: _AddOption.upload,
        ),
        PdSheetOption(
          icon: LucideIcons.pencil,
          title: 'Type it in',
          description: 'Add the details by hand.',
          value: _AddOption.manual,
        ),
      ],
    );
    if (!context.mounted) return;
    switch (option) {
      case _AddOption.camera:
        context.push(Routes.camera);
      case _AddOption.upload:
        final files = await chooseOriginals(context);
        if (!context.mounted || files.isEmpty) return;
        context.push(Routes.reading, extra: files);
      case _AddOption.manual:
        context.push(Routes.details, extra: const AddDetailsArgs());
      case null:
        return;
    }
  }

  static Future<void> camera(BuildContext context) async {
    if (await _showLimitIfNeeded(context) || !context.mounted) return;
    context.push(Routes.camera);
  }

  static Future<List<PendingFile>> chooseOriginals(BuildContext context) async {
    final source = await showPdActions<_UploadSource>(
      context,
      title: 'Choose a photo or PDF',
      actions: const [
        PdAction(label: 'Choose from Photos', value: _UploadSource.photos),
        PdAction(label: 'Browse Files', value: _UploadSource.files),
      ],
    );
    if (!context.mounted || source == null) return const [];
    final capture = context.read<CaptureService>();
    try {
      return await (source == _UploadSource.photos
          ? capture.pickPhotos()
          : capture.pickFiles());
    } catch (_) {
      if (context.mounted) {
        showPdSnackbar(
          context,
          'The picker couldn’t open. Try again or type it in.',
        );
      }
      return const [];
    }
  }

  static Future<bool> _showLimitIfNeeded(BuildContext context) async {
    final items = context.read<ItemRepository>();
    if (!items.atLimit) return false;
    // The buttons are built under the sheet's navigator so only it is closed.
    final action = await showPdSheet<_LimitAction>(
      context,
      title: 'Your Base drawer is full',
      body: Builder(
        builder: (sheetContext) => LimitNotice(
          count: items.activeCount,
          onReview: () => Navigator.of(sheetContext).pop(_LimitAction.review),
          onWaitlist: () =>
              Navigator.of(sheetContext).pop(_LimitAction.waitlist),
        ),
      ),
    );
    if (!context.mounted) return true;
    switch (action) {
      case _LimitAction.review:
        context.go('${Routes.vault}?review=old');
      case _LimitAction.waitlist:
        await showPdSheet<void>(
          context,
          title: 'PaperDrawer Pro',
          subtitle: 'The Pro waitlist is opening soon.',
        );
      case null:
        break;
    }
    return true;
  }
}
