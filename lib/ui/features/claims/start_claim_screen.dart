import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/item_repository.dart';
import '../../../domain/formats.dart';
import '../../../domain/ladders.dart';
import '../../../domain/models/claim.dart';
import '../../../domain/models/item.dart';
import '../../../routing/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/nav.dart';
import '../../core/widgets/paper.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/text_field.dart';
import 'start_claim_view_model.dart';

class StartClaimScreen extends StatelessWidget {
  const StartClaimScreen({required this.itemId, super.key});

  final String itemId;

  @override
  Widget build(BuildContext context) {
    final item = context.select<ItemRepository, Item?>((items) => items.byId(itemId));
    if (item == null) {
      return PdPushedScaffold(
        backLabel: 'Vault',
        title: 'Start a claim',
        children: [
          DashedTile(
            title: 'This item is missing',
            body: 'Choose an item in your vault to start a claim.',
            action: PdButton.primary(
              label: 'Open vault',
              onPressed: () => context.go(Routes.vault),
            ),
          ),
        ],
      );
    }
    return _StartClaimForm(key: ValueKey(item.id), item: item);
  }
}

class _StartClaimForm extends StatefulWidget {
  const _StartClaimForm({required this.item, super.key});

  final Item item;

  @override
  State<_StartClaimForm> createState() => _StartClaimFormState();
}

class _StartClaimFormState extends State<_StartClaimForm> {
  final _description = TextEditingController();
  final _reference = TextEditingController();

  late final _model = StartClaimViewModel(
    widget.item,
    context.read(),
    context.read(),
  );
  late final _existing = _model.existing;

  @override
  void dispose() {
    _description.dispose();
    _reference.dispose();
    _model.dispose();
    super.dispose();
  }

  void _openClaim(String id) {
    final router = GoRouter.of(context);
    if (router.canPop()) router.pop();
    router.go(Routes.claim(id));
  }

  Future<void> _chooseDate() async {
    final date = await showPdDatePicker(
      context,
      title: 'When did you notice?',
      initial: _model.noticedOn,
      max: _model.today,
    );
    if (!mounted || date == null) return;
    _model.selectNoticedOn(date);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final claim = await _model.save(_reference.text);
    if (!mounted || claim == null) return;
    _openClaim(claim.id);
  }

  @override
  Widget build(BuildContext context) {
    final existing = _existing;
    if (existing != null) {
      return PdPushedScaffold(
        backLabel: 'Vault',
        title: 'Start a claim',
        children: [
          DashedTile(
            title: 'There’s already an open claim',
            body: 'Keep tracking your claim for ${widget.item.name}.',
            action: PdButton.primary(
              label: 'Open claim',
              onPressed: () => _openClaim(existing.id),
            ),
          ),
        ],
      );
    }

    return ListenableBuilder(
      listenable: _model,
      builder: (context, _) => PdPushedScaffold(
        backLabel: 'Vault',
        kicker: 'NEW CLAIM',
        title: 'What went wrong?',
        bottom: PdButton.primary(
          key: const ValueKey('save-claim'),
          label: 'Save claim',
          onPressed: _model.canSave ? _save : null,
          expand: true,
          busy: _model.busy,
        ),
        children: [
          _ClaimItem(item: widget.item),
          const SizedBox(height: Pd.s6),
          const _FieldLabel('TYPE OF CLAIM'),
          const SizedBox(height: Pd.s2),
          Wrap(
            spacing: Pd.s2,
            runSpacing: Pd.s2,
            children: [
              for (final type in ClaimType.values)
                PdChoiceChip(
                  key: ValueKey('claim-type-${type.name}'),
                  label: type.choice,
                  selected: _model.type == type,
                  onPaper: false,
                  onTap: () => _model.selectType(type),
                ),
            ],
          ),
          const SizedBox(height: Pd.s4),
          PdTextField(
            label: 'WHAT HAPPENED',
            controller: _description,
            fieldKey: const ValueKey('claim-problem'),
            hint: 'Describe the issue in your own words.',
            help: 'This goes into the message we draft for you.',
            onChanged: _model.describe,
            enabled: !_model.busy,
            validator: (value) => value.trim().isEmpty
                ? 'Describe what happened.'
                : null,
            maxLines: 4,
          ),
          const SizedBox(height: Pd.s4),
          PdFieldButton(
            key: const ValueKey('claim-noticed-date'),
            label: 'WHEN DID YOU NOTICE?',
            value: longDate(_model.noticedOn),
            onTap: _chooseDate,
          ),
          const SizedBox(height: Pd.s4),
          const _FieldLabel('WHAT WOULD HELP?'),
          const SizedBox(height: Pd.s2),
          Wrap(
            spacing: Pd.s2,
            runSpacing: Pd.s2,
            children: [
              for (final want in _model.wants)
                PdChoiceChip(
                  key: ValueKey('claim-want-${want.name}'),
                  label: want.chip,
                  selected: _model.want == want,
                  onPaper: false,
                  onTap: () => _model.selectWant(want),
                ),
            ],
          ),
          const SizedBox(height: Pd.s4),
          PdTextField(
            label: 'TICKET OR CLAIM NUMBER',
            controller: _reference,
            hint: 'Optional',
            fieldKey: const ValueKey('claim-reference'),
            enabled: !_model.busy,
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: Pd.s4),
          Text(
            'First step · ${firstRungTitle(_model.type)}',
            style: PdType.bodyStrong,
          ),
          const SizedBox(height: Pd.s1),
          Text(
            ladderFor(_model.type).first.guidance,
            style: PdType.footnote.copyWith(color: Pd.textMuted),
          ),
          if (_model.error case final error?) ...[
            const SizedBox(height: Pd.s3),
            Semantics(
              liveRegion: true,
              child: Text(error, style: PdType.footnote.copyWith(color: Pd.signal)),
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Text(label, style: PdType.label.copyWith(color: Pd.textMuted));
}

class _ClaimItem extends StatelessWidget {
  const _ClaimItem({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) => DocumentPaper(
    padding: const EdgeInsets.all(Pd.s4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ITEM IN YOUR VAULT', style: PdType.label.copyWith(color: Pd.inkMuted)),
        const SizedBox(height: Pd.s2),
        Text(item.name, style: PdType.cardTitle.copyWith(color: Pd.ink)),
        if (item.draft.source.isNotEmpty) ...[
          const SizedBox(height: Pd.s1),
          Text(item.draft.source, style: PdType.callout.copyWith(color: Pd.ink2)),
        ],
      ],
    ),
  );
}
