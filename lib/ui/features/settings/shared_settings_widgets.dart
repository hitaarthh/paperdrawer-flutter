import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart' show RefreshIndicator, Scaffold;

import '../../../domain/item_status.dart';
import '../../../routing/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/brand_bar.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/meter.dart';
import '../../core/widgets/nav.dart';
import '../../core/widgets/paper.dart';

enum SettingsDestination { account, plan, notifications, data }

class SettingsOverview extends StatelessWidget {
  const SettingsOverview({
    required this.account,
    required this.version,
    this.plan,
    this.notifications,
    this.controller,
    this.onRefresh,
    super.key,
  });

  final Widget account;
  final Future<String?> version;
  final String? plan;
  final String? notifications;
  final ScrollController? controller;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final refresh = onRefresh;
    final list = ListView(
      key: const PageStorageKey('settings-scroll'),
      controller: controller,
      physics: refresh == null ? null : const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        Pd.margin,
        Pd.s3,
        Pd.margin,
        Pd.s8 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Semantics(
          header: true,
          child: Text('Settings', style: PdType.heroTitle),
        ),
        const SizedBox(height: Pd.s6),
        account,
        const SizedBox(height: Pd.s5),
        SettingsMenu(
          children: [
            PdListRow(
              key: const ValueKey('settings-plan'),
              title: 'Plan',
              value: plan,
              leadingIcon: LucideIcons.layers,
              chevron: true,
              onTap: () => context.push(Routes.settingsPlan),
            ),
            PdListRow(
              key: const ValueKey('settings-open-notifications'),
              title: 'Reminders & notifications',
              value: notifications,
              leadingIcon: LucideIcons.bell,
              chevron: true,
              onTap: () => context.push(Routes.settingsNotifications),
            ),
            PdListRow(
              key: const ValueKey('settings-data'),
              title: 'Your data',
              leadingIcon: LucideIcons.database,
              chevron: true,
              onTap: () => context.push(Routes.settingsData),
            ),
            PdListRow(
              key: const ValueKey('settings-legal'),
              title: 'Legal',
              leadingIcon: LucideIcons.bookOpen,
              chevron: true,
              onTap: () => context.push(Routes.legal),
            ),
          ],
        ),
        FutureBuilder(
          future: version,
          builder: (context, state) {
            if (state.data case final value?) {
              return Padding(
                padding: const EdgeInsets.only(top: Pd.s4),
                child: SharedSettingsDetail('Version $value', mono: true),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
    return Scaffold(
      backgroundColor: Pd.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Pd.maxContent),
          child: Column(
            children: [
              const PdBrandBar(),
              Expanded(
                child: refresh == null
                    ? list
                    : RefreshIndicator.adaptive(
                        onRefresh: refresh,
                        child: list,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsSubpage extends StatelessWidget {
  const SettingsSubpage({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => PdPushedScaffold(
    title: title,
    titleStyle: PdType.trackerTitle,
    backLabel: 'Settings',
    glassBack: true,
    onBack: () =>
        context.canPop() ? context.pop() : context.go(Routes.settings),
    children: children,
  );
}

class SettingsMenu extends StatelessWidget {
  const SettingsMenu({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => PdListGroup(children: children);
}

class SettingsAccountCard extends StatelessWidget {
  const SettingsAccountCard({
    required this.name,
    required this.description,
    this.initials,
    super.key,
  });

  final String name;
  final String? description;
  final String? initials;

  static const _stubWidth = Pd.tapMin + 2 * Pd.s3;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: CupertinoButton(
      key: const ValueKey('settings-account'),
      onPressed: () => context.push(Routes.settingsAccount),
      focusColor: Pd.lime,
      padding: EdgeInsets.zero,
      pressedOpacity: .78,
      child: RepaintBoundary(
        child: NotchedTicketPaper(
          stubWidth: _stubWidth,
          child: Row(
            children: [
              SizedBox(
                width: _stubWidth,
                child: Center(child: ExcludeSemantics(child: _identityMark())),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    Pd.s4,
                    Pd.s4,
                    Pd.s2,
                    Pd.s4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: Pd.s1,
                    children: [
                      Text(
                        'ACCOUNT',
                        style: PdType.label.copyWith(color: Pd.inkMuted),
                      ),
                      Text(name, style: PdType.title2.copyWith(color: Pd.ink)),
                      if (description case final detail?)
                        Text(
                          detail,
                          style: PdType.detail.copyWith(color: Pd.ink2),
                        ),
                    ],
                  ),
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                color: Pd.inkMuted,
                size: Pd.iconSm,
              ),
              const SizedBox(width: Pd.margin),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _identityMark() => SizedBox.square(
    dimension: Pd.tapMin,
    child: DecoratedBox(
      decoration: const BoxDecoration(color: Pd.ink, shape: BoxShape.circle),
      child: Padding(
        padding: const EdgeInsets.all(Pd.s2),
        child: Center(
          child: initials == null
              ? const Icon(
                  LucideIcons.smartphone,
                  color: Pd.lime,
                  size: Pd.iconMd,
                )
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    initials!,
                    style: PdType.monoButton.copyWith(color: Pd.lime),
                  ),
                ),
        ),
      ),
    ),
  );
}

class SharedSettingsDetail extends StatelessWidget {
  const SharedSettingsDetail(this.text, {this.mono = false, super.key});

  final String text;
  final bool mono;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: (mono ? PdType.meta : PdType.detail).copyWith(color: Pd.textMuted),
  );
}

class SharedSettingsLink extends StatelessWidget {
  const SharedSettingsLink({
    required this.label,
    required this.onPressed,
    this.accent = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool accent;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: const Size.square(Pd.tapMin),
    focusColor: Pd.lime,
    onPressed: onPressed,
    child: Text(
      label.toUpperCase(),
      semanticsLabel: label,
      style: accent
          ? PdType.monoButton.copyWith(color: Pd.lime)
          : PdType.meta.copyWith(color: Pd.textMuted),
    ),
  );
}

class SettingsPlanCard extends StatelessWidget {
  const SettingsPlanCard({
    required this.used,
    this.onBase = true,
    this.failed = false,
    this.onRetry,
    super.key,
  });

  final int? used;
  final bool onBase;
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final used = this.used;
    return Container(
      padding: const EdgeInsets.all(Pd.s4),
      decoration: BoxDecoration(
        color: Pd.surface2,
        borderRadius: BorderRadius.circular(Pd.rSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Pd.s2,
        children: [
          if (used != null) ...[
            Row(
              spacing: Pd.s2,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    onBase ? 'BASE · FREE' : 'PRO',
                    style: PdType.monoButton.copyWith(color: Pd.lime),
                  ),
                ),
                Flexible(
                  child: Text(
                    onBase
                        ? '$used OF $baseItemLimit ITEMS'
                        : '$used ${used == 1 ? 'ITEM' : 'ITEMS'}',
                    textAlign: TextAlign.end,
                    style: PdType.data,
                  ),
                ),
              ],
            ),
            if (onBase) ...[
              MeterBar(fraction: used / baseItemLimit),
              const SharedSettingsDetail(
                'Reminders and export stay available when your drawer is full.',
              ),
            ] else
              const SharedSettingsDetail('Your plan includes unlimited items.'),
          ] else
            Semantics(
              liveRegion: true,
              child: SharedSettingsDetail(
                failed ? 'Couldn’t load plan usage.' : 'Loading plan usage…',
              ),
            ),
          if (used == null && failed && onRetry != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: SharedSettingsLink(label: 'Retry', onPressed: onRetry!),
            ),
        ],
      ),
    );
  }
}
