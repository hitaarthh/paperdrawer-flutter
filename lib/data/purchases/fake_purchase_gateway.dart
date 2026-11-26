import 'dart:async';

import '../../core/failure/app_failure.dart';
import '../../core/result/result.dart';
import '../../core/time/clock.dart';
import '../../domain/account/account_scope.dart';
import '../../domain/plans/entitlement.dart';
import '../../domain/plans/plan.dart';
import '../../domain/plans/purchase_gateway.dart';
import '../../domain/plans/purchase_products.dart';

/// The purchase service's server side, for fakes: which customer owns which
/// grants. Share one ledger between several [FakePurchaseGateway]s to model
/// several phones (a new iPhone, a reinstall).
final class FakePurchaseLedger {
  final Map<String, List<PlanGrant>> _owned = {};

  List<PlanGrant> grantsOf(String customerId) =>
      List.unmodifiable(_owned[customerId] ?? const <PlanGrant>[]);

  void grant(String customerId, PlanGrant grant) =>
      (_owned[customerId] ??= []).add(grant);

  /// A refund or chargeback: the customer loses [plan].
  void revoke(String customerId, Plan plan) =>
      _owned[customerId]?.removeWhere((grant) => grant.plan == plan);

  /// RevenueCat's log-in rule: an anonymous customer's purchases move to the
  /// account only when the account owns nothing yet. Otherwise they stay
  /// where they are (a purchase never moves between accounts).
  void attachAnonymous(String anonymousId, String accountId) {
    final anonymous = _owned[anonymousId];
    if (anonymous == null || anonymous.isEmpty) return;
    if ((_owned[accountId] ?? const <PlanGrant>[]).isNotEmpty) return;
    _owned[accountId] = [...anonymous];
    anonymous.clear();
  }
}

/// [PurchaseGateway] for tests and the simulator: no store, no network.
///
/// Prices are labelled as placeholders, never real prices. Inject failures
/// with [failNextWith]; make purchases wait for approval with
/// [purchasesPending] and finish them with [completePending].
final class FakePurchaseGateway implements PurchaseGateway {
  FakePurchaseGateway({
    required Clock clock,
    FakePurchaseLedger? ledger,
    this.anonymousId = r'$RCAnonymousID:fake',
    List<ProductOffer>? offers,
  }) : _clock = clock,
       ledger = ledger ?? FakePurchaseLedger(),
       _offers = offers ?? _placeholderOffers;

  static final List<ProductOffer> _placeholderOffers = [
    for (final product in PurchaseProducts.forSale)
      ProductOffer(
        product: product,
        displayPrice: 'Price from store',
        currencyCode: 'INR',
      ),
  ];

  final Clock _clock;
  final FakePurchaseLedger ledger;
  final String anonymousId;
  final List<ProductOffer> _offers;
  final StreamController<Entitlements> _changes =
      StreamController<Entitlements>.broadcast();
  final List<PurchaseProduct> _pending = [];

  String? _accountId;

  /// The next call that reaches the store fails with this, once.
  AppFailure? failNextWith;

  /// Purchases end `PurchaseFailure(pending)` until [completePending].
  bool purchasesPending = false;

  /// The customer purchases are recorded against now.
  String get customerId => _accountId ?? anonymousId;

  @override
  Future<Result<List<ProductOffer>>> products() async =>
      _failure<List<ProductOffer>>() ?? Ok(List.unmodifiable(_offers));

  @override
  Future<Result<Entitlements>> currentEntitlements() async =>
      _failure<Entitlements>() ?? Ok(_entitlements());

  @override
  Future<Result<Entitlements>> purchase(PurchaseProduct product) async {
    final failure = _failure<Entitlements>();
    if (failure != null) return failure;
    if (purchasesPending) {
      _pending.add(product);
      return const Err<Entitlements>(
        PurchaseFailure(PurchaseFailureKind.pending),
      );
    }
    ledger.grant(customerId, _grantFor(product));
    return Ok(_entitlements());
  }

  @override
  Future<Result<Entitlements>> restore() async =>
      _failure<Entitlements>() ?? Ok(_entitlements());

  @override
  Future<Result<Entitlements>> logIn(UserScope scope) async {
    final failure = _failure<Entitlements>();
    if (failure != null) return failure;
    if (_accountId == null) ledger.attachAnonymous(anonymousId, scope.id);
    _accountId = scope.id;
    return Ok(_entitlements());
  }

  @override
  Future<Result<Unit>> logOut() async {
    final failure = _failure<Unit>();
    if (failure != null) return failure;
    _accountId = null;
    return const Ok(unit);
  }

  @override
  Stream<Entitlements> get entitlementChanges => _changes.stream;

  /// Ask to Buy approved: records the waiting purchases and reports them.
  void completePending() {
    if (_pending.isEmpty) return;
    for (final product in _pending) {
      ledger.grant(customerId, _grantFor(product));
    }
    _pending.clear();
    _changes.add(_entitlements());
  }

  /// The store refunded [plan]: reports the lower entitlements.
  void refund(Plan plan) {
    ledger.revoke(customerId, plan);
    _changes.add(_entitlements());
  }

  Future<void> dispose() => _changes.close();

  PlanGrant _grantFor(PurchaseProduct product) {
    final now = _clock.now();
    return PlanGrant(
      plan: product.plan,
      store: PurchaseStore.appStore,
      expiresAt: switch (product.billing) {
        ProductBilling.oneTime => null,
        ProductBilling.monthly => now.add(const Duration(days: 30)),
        ProductBilling.yearly => now.add(const Duration(days: 365)),
      },
    );
  }

  Entitlements _entitlements() =>
      Entitlements(grants: ledger.grantsOf(customerId), verifiedAt: _clock.now());

  Err<T>? _failure<T>() {
    final failure = failNextWith;
    if (failure == null) return null;
    failNextWith = null;
    return Err<T>(failure);
  }
}
