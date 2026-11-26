import '../../core/failure/failure_mapper.dart';
import '../../core/logging/app_logger.dart';
import '../../core/result/result.dart';
import '../../core/time/clock.dart';
import '../../domain/account/account_scope.dart';
import '../../domain/plans/entitlement.dart';
import '../../domain/plans/purchase_gateway.dart';
import '../../domain/plans/purchase_products.dart';
import '../errors/network_failure_rule.dart';
import 'customer_entitlements.dart';
import 'revenuecat_client.dart';
import 'revenuecat_failure_rule.dart';

/// [PurchaseGateway] over RevenueCat (App Store now, Play Store later).
///
/// Purchases belong to the PaperDrawer account: after [logIn], every
/// purchase and restore first checks that RevenueCat still identifies the
/// customer as that account, and logs in again if it doesn't, so a purchase
/// can never be recorded against someone else. Whether a restore may move a
/// purchase from another account is RevenueCat's "Restore behavior"
/// project setting, which must be "Keep with original App User ID".
///
/// Failure cases: see [PurchaseGateway]. Store codes are mapped by
/// [RevenueCatFailureRule]; build the mapper with [failureMapper].
final class RevenueCatPurchaseGateway implements PurchaseGateway {
  RevenueCatPurchaseGateway({
    required RevenueCatClient client,
    required Clock clock,
    required AppLogger logger,
    required FailureMapper failures,
  }) : _client = client,
       _clock = clock,
       _logger = logger,
       _failures = failures;

  /// The mapper this gateway expects: RevenueCat codes, then network errors.
  static FailureMapper failureMapper() => FailureMapper(
    extraRules: const [RevenueCatFailureRule(), NetworkFailureRule()],
  );

  final RevenueCatClient _client;
  final Clock _clock;
  final AppLogger _logger;
  final FailureMapper _failures;

  /// The account purchases must belong to; `null` for a guest.
  String? _accountId;

  @override
  Future<Result<List<ProductOffer>>> products() =>
      _guard('products', () async {
        final found = await _client.products(
          oneTime: {
            for (final p in PurchaseProducts.forSale)
              if (!p.isSubscription) p.id,
          },
          subscriptions: {
            for (final p in PurchaseProducts.forSale)
              if (p.isSubscription) p.id,
          },
        );
        final byId = {for (final product in found) product.id: product};
        return Ok([
          for (final product in PurchaseProducts.forSale)
            if (byId[product.id] case final store?)
              ProductOffer(
                product: product,
                displayPrice: store.displayPrice,
                currencyCode: store.currencyCode,
              ),
        ]);
      });

  @override
  Future<Result<Entitlements>> currentEntitlements() =>
      _guard('currentEntitlements', () async => Ok(_map(await _client.customer())));

  @override
  Future<Result<Entitlements>> purchase(PurchaseProduct product) =>
      _guard('purchase', () async {
        await _ensureAccount();
        final customer = await _client.purchase(
          product.id,
          subscription: product.isSubscription,
        );
        _logger.info('Purchase completed: ${product.id}');
        return Ok(_map(customer));
      });

  @override
  Future<Result<Entitlements>> restore() => _guard('restore', () async {
    await _ensureAccount();
    return Ok(_map(await _client.restore()));
  });

  @override
  Future<Result<Entitlements>> logIn(UserScope scope) =>
      _guard('logIn', () async {
        final customer = await _client.logIn(scope.id);
        _accountId = scope.id;
        return Ok(_map(customer));
      });

  @override
  Future<Result<Unit>> logOut() => _guard('logOut', () async {
    _accountId = null;
    if (await _client.isAnonymous()) return const Ok(unit);
    await _client.logOut();
    return const Ok(unit);
  });

  @override
  Stream<Entitlements> get entitlementChanges =>
      _client.customerUpdates.map(_map);

  /// Logs in again when RevenueCat's customer drifted from the account
  /// (the SDK was reset, or another code path logged out).
  Future<void> _ensureAccount() async {
    final account = _accountId;
    if (account == null) return;
    if (await _client.appUserId() == account) return;
    _logger.warning('RevenueCat customer drifted; logging in again');
    await _client.logIn(account);
  }

  Entitlements _map(RevenueCatCustomer customer) =>
      CustomerEntitlements.map(customer, _clock.now());

  Future<Result<T>> _guard<T>(
    String where,
    Future<Result<T>> Function() body,
  ) async {
    try {
      return await body();
    } catch (error, stackTrace) {
      final failure = _failures.map(error, stackTrace);
      _logger.failure('RevenueCatPurchaseGateway.$where', failure);
      return Err<T>(failure);
    }
  }
}
