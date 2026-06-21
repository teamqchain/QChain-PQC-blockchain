import 'dart:convert';
import 'package:qportal_webapp/models/VERIFIER/alert_model.dart';
import 'package:qportal_webapp/models/VERIFIER/subscription_model.dart';
import 'package:qportal_webapp/services/core_api.dart';
import 'package:qportal_webapp/utils/webApp_config.dart';
import 'package:qportal_webapp/utils/logger.dart';

class SubscriptionApi {
  // ─── SUBSCRIPTIONS ───────────────────────────────────────────────────────────

  // POST /requestSubscription
  static Future<bool> requestSubscription(String credentialID) async {
    logDebug(
      '[SubscriptionApi] requestSubscription called for credentialID: $credentialID',
    );
    if (!await ApiCore.ensureConnection()) {
      logDebug(
        '[SubscriptionApi] requestSubscription blocked: backend disconnected',
      );
      throw ConnectionException();
    }
    try {
      final res = await ApiCore.client.post(
        Uri.parse('$kApiBaseUrl/requestSubscription'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'credentialID': credentialID}),
      );
      if (res.statusCode != 200) {
        logDebug(
          '[SubscriptionApi] requestSubscription failed: HTTP ${res.statusCode}',
        );
        return false;
      }

      logDebug('[SubscriptionApi] requestSubscription success');
      return true;
    } catch (e) {
      logDebug('[SubscriptionApi] requestSubscription exception: $e');
      throw ConnectionException();
    }
  }

  // GET /getSubscriptions
  static Future<List<SubscriptionRecord>> getSubscriptions({
    int page = 1,
    int limit = 100,
  }) async {
    logDebug(
      '[SubscriptionApi] getSubscriptions called (page: $page, limit: $limit)',
    );
    if (!await ApiCore.ensureConnection()) {
      logDebug(
        '[SubscriptionApi] getSubscriptions blocked: backend disconnected',
      );
      throw ConnectionException();
    }
    try {
      final res = await ApiCore.client.get(
        Uri.parse('$kApiBaseUrl/getSubscriptions?page=$page&limit=$limit'),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = body['subscriptions'] as List? ?? [];
        logDebug(
          '[SubscriptionApi] getSubscriptions success: fetched ${list.length} subscriptions',
        );
        return list
            .map((e) => SubscriptionRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      logDebug(
        '[SubscriptionApi] getSubscriptions failed: HTTP ${res.statusCode}',
      );
      return [];
    } catch (e) {
      logDebug('[SubscriptionApi] getSubscriptions exception: $e');
      throw ConnectionException();
    }
  }

  // POST /deleteSubscription
  static Future<bool> deleteSubscription(String subscriptionID) async {
    logDebug(
      '[SubscriptionApi] deleteSubscription called for subscriptionID: $subscriptionID',
    );
    if (!await ApiCore.ensureConnection()) {
      logDebug(
        '[SubscriptionApi] deleteSubscription blocked: backend disconnected',
      );
      throw ConnectionException();
    }
    try {
      final res = await ApiCore.client.post(
        Uri.parse('$kApiBaseUrl/deleteSubscription'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'subscriptionID': subscriptionID}),
      );
      if (res.statusCode != 200) {
        logDebug(
          '[SubscriptionApi] deleteSubscription failed: HTTP ${res.statusCode}',
        );
        return false;
      }

      logDebug('[SubscriptionApi] deleteSubscription success');
      return true;
    } catch (e) {
      logDebug('[SubscriptionApi] deleteSubscription exception: $e');
      throw ConnectionException();
    }
  }

  // POST /unsubscribe
  static Future<bool> unsubscribe(String subscriptionID) async {
    logDebug(
      '[SubscriptionApi] unsubscribe called for subscriptionID: $subscriptionID',
    );
    if (!await ApiCore.ensureConnection()) {
      logDebug('[SubscriptionApi] unsubscribe blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await ApiCore.client.post(
        Uri.parse('$kApiBaseUrl/unsubscribe'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'subscriptionID': subscriptionID}),
      );
      if (res.statusCode != 200) {
        logDebug(
          '[SubscriptionApi] unsubscribe failed: HTTP ${res.statusCode}',
        );
        return false;
      }

      logDebug('[SubscriptionApi] unsubscribe success');
      return true;
    } catch (e) {
      logDebug('[SubscriptionApi] unsubscribe exception: $e');
      throw ConnectionException();
    }
  }

  // ─── ALERTS ──────────────────────────────────────────────────────────────────

  // GET /getSubscriptionAlerts
  static Future<List<LiveAlertRecord>> getSubscriptionAlerts() async {
    logDebug('[SubscriptionApi] getSubscriptionAlerts called');
    if (!await ApiCore.ensureConnection()) {
      logDebug(
        '[SubscriptionApi] getSubscriptionAlerts blocked: backend disconnected',
      );
      throw ConnectionException();
    }
    try {
      final res = await ApiCore.client.get(
        Uri.parse('$kApiBaseUrl/getSubscriptionAlerts'),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = body['alerts'] as List? ?? [];
        logDebug(
          '[SubscriptionApi] getSubscriptionAlerts success: fetched ${list.length} alerts',
        );
        return list
            .map((e) => LiveAlertRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      logDebug(
        '[SubscriptionApi] getSubscriptionAlerts failed: HTTP ${res.statusCode}',
      );
      return [];
    } catch (e) {
      logDebug('[SubscriptionApi] getSubscriptionAlerts exception: $e');
      throw ConnectionException();
    }
  }

  // POST /acknowledgeAlert
  static Future<bool> acknowledgeAlert(String alertID) async {
    logDebug('[SubscriptionApi] acknowledgeAlert called for alertID: $alertID');
    if (!await ApiCore.ensureConnection()) {
      logDebug(
        '[SubscriptionApi] acknowledgeAlert blocked: backend disconnected',
      );
      throw ConnectionException();
    }
    try {
      final res = await ApiCore.client.post(
        Uri.parse('$kApiBaseUrl/acknowledgeAlert'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'alertID': alertID}),
      );
      if (res.statusCode != 200) {
        logDebug(
          '[SubscriptionApi] acknowledgeAlert failed: HTTP ${res.statusCode}',
        );
        return false;
      }

      logDebug('[SubscriptionApi] acknowledgeAlert success');
      return true;
    } catch (e) {
      logDebug('[SubscriptionApi] acknowledgeAlert exception: $e');
      throw ConnectionException();
    }
  }
}
