import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/item_repository.dart';
import '../../../data/services/capture_service.dart';
import '../../../domain/models/item.dart';
import '../../../routing/router.dart';
import '../../core/widgets/limit_notice.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/snackbar.dart';
import 'add_details_args.dart';
import 'add_sheet.dart';

enum _UploadSource { photos, files }

enum _LimitAction { review, waitlist }

abstract final class AddFlow {
  /// Opens the Add sheet ("Scan or add"), or the limit notice when the Base
  /// drawer is full, then routes to the camera, the pickers or the form.
  static Future<void> start(BuildContext context) async {
    if (await _showLimitIfNeeded(context) || !context.mounted) return;
    final choice = await showAddSheet(
      context,
      used: context.read<ItemRepository>().activeCount,
    );
    if (!context.mounted || choice == null) return;
    switch (choice.action) {
      case AddSheetAction.camera:
        context.push(Routes.camera, extra: choice.kind);
      case AddSheetAction.upload:
        final files = await chooseOriginals(context);
        if (!context.mounted || files.isEmpty) return;
        context.push(
          Routes.reading,
          extra: CaptureReadingArgs(files, kind: choice.kind),
        );
      case AddSheetAction.manual:
        context.push(Routes.details, extra: AddDetailsArgs(kind: choice.kind));
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
          title: 'Paper Drawer Pro',
          subtitle: 'The Pro waitlist is opening soon.',
        );
      case null:
        break;
    }
    return true;
  }
}
