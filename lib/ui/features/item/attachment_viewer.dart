import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/models/item.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';

/// A thumbnail that hands the original to the device's document viewer.
class AttachmentViewer extends StatefulWidget {
  const AttachmentViewer({
    required this.attachment,
    required this.thumbnail,
    required this.onOpen,
    super.key,
  });

  final Attachment attachment;
  final Future<Uint8List?> Function(Attachment) thumbnail;
  final VoidCallback? onOpen;

  @override
  State<AttachmentViewer> createState() => _AttachmentViewerState();
}

class _AttachmentViewerState extends State<AttachmentViewer> {
  late Future<Uint8List?> _preview = widget.thumbnail(widget.attachment);

  @override
  void didUpdateWidget(covariant AttachmentViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.path != widget.attachment.path) {
      _preview = widget.thumbnail(widget.attachment);
    }
  }

  @override
  Widget build(BuildContext context) {
    final document = widget.attachment;
    final placeholder = Center(child: Icon(
      document.isPdf ? LucideIcons.fileText : LucideIcons.image,
      size: Pd.iconMd,
      color: Pd.textMuted,
    ));
    return SizedBox(
      width: Pd.s12 + Pd.s6,
      child: Semantics(
        button: true,
        label: 'Open ${document.name}',
        excludeSemantics: true,
        onTap: widget.onOpen,
        child: CupertinoButton(
          onPressed: widget.onOpen,
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Pd.rSm),
                  child: ColoredBox(
                    color: Pd.surface2,
                    child: FutureBuilder(
                      future: _preview,
                      builder: (context, state) {
                        final data = state.data;
                        if (data == null) return placeholder;
                        return Image.memory(
                          data,
                          cacheWidth: (MediaQuery.devicePixelRatioOf(context) * (Pd.s12 + Pd.s6)).ceil(),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => placeholder,
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Pd.s1),
              Text(document.name, style: PdType.footnote, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
