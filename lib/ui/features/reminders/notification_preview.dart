import 'package:cupertino_ui/cupertino_ui.dart';

import '../../../domain/formats.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/icons.dart';

/// App-icon tile in the sample notifications (iOS Reminders mockup).
const _iconTile = 38.0;
const _iconRadius = 9.0;
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Two sample lock-screen notifications: a return window closing in two days
/// (dated from [today]) and a policy renewal fading behind it.
class NotificationPreview extends StatelessWidget {
  const NotificationPreview({required this.today, super.key});

  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final returnBy = addDays(today, 2);
    final date = '${_weekdays[returnBy.weekday - 1]} ${shortDate(returnBy)}';
    const title = 'Return window closes in 2 days';
    final body = 'Wireless earbuds · return by $date';
    return Semantics(
      label: 'Example notification. $title. Wireless earbuds, return by $date.',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Pd.s3,
        children: [
          _Notice(title: title, body: body, header: true),
          Opacity(
            opacity: 0.6,
            child: Transform.scale(
              scale: 0.96,
              child: const _Notice(
                title: 'Family health policy renews in 12 days',
                body: 'Renew to keep your no-claim bonus',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.body, this.header = false});

  final String title;
  final String body;

  /// The front notification carries the app name and time, and a shadow.
  final bool header;

  @override
  Widget build(BuildContext context) {
    final caption = PdType.tabLabel.copyWith(color: Pd.textMuted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Pd.s4, vertical: Pd.s3),
      decoration: BoxDecoration(
        color: Pd.surface2,
        borderRadius: BorderRadius.circular(Pd.rMd),
        border: Border.all(color: Pd.hairline),
        boxShadow: header ? Pd.shadowFab : null,
      ),
      child: Row(
        spacing: Pd.s3,
        children: [
          Container(
            width: _iconTile,
            height: _iconTile,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Pd.bg,
              borderRadius: BorderRadius.circular(_iconRadius),
            ),
            child: const PaperDrawerMark(size: 20),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (header)
                  Row(
                    children: [
                      Expanded(child: Text('PAPERDRAWER', style: caption)),
                      Text('NOW', style: caption),
                    ],
                  ),
                Text(
                  title,
                  style: PdType.callout.copyWith(
                    color: Pd.text,
                    fontWeight: FontWeight.w600,
                    fontVariations: const [FontVariation.weight(600)],
                  ),
                ),
                Text(
                  body,
                  style: PdType.footnote.copyWith(color: Pd.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The mockups' `.grain`: a 1px dot every 4px at 3.5% white.
class PaperGrain extends CustomPainter {
  const PaperGrain();

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = const Color(0x09FFFFFF);
    for (double y = 2; y < size.height; y += 4) {
      for (double x = 2; x < size.width; x += 4) {
        canvas.drawCircle(Offset(x, y), 0.5, dot);
      }
    }
  }

  @override
  bool shouldRepaint(PaperGrain oldDelegate) => false;
}
