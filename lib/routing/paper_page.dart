import 'package:cupertino_ui/cupertino_ui.dart';

import '../ui/core/theme/tokens.dart';
import '../ui/core/widgets/glass.dart';

/// Keeps both pages live while navigating around native platform views.
class PdPage<T> extends CupertinoPage<T> {
  const PdPage({
    required super.child,
    required super.key,
    super.fullscreenDialog,
  }) : super(allowSnapshotting: false);

  @override
  Route<T> createRoute(BuildContext context) => _PdPageRoute<T>(this);
}

class _PdPageRoute<T> extends PageRoute<T>
    with CupertinoRouteTransitionMixin<T> {
  _PdPageRoute(PdPage<T> page)
    : super(settings: page, allowSnapshotting: false);

  PdPage<T> get _page => settings as PdPage<T>;

  @override
  Duration get transitionDuration => Pd.sheetDuration;

  @override
  bool get maintainState => _page.maintainState;

  @override
  bool get fullscreenDialog => _page.fullscreenDialog;

  @override
  String? get title => _page.title;

  @override
  Widget buildContent(BuildContext context) =>
      PdGlassRouteBoundary(child: _page.child);
}
