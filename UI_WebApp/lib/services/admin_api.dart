import 'dart:convert';
import 'package:qportal_webapp/models/IT_ADMIN/audit_model.dart';
import 'package:qportal_webapp/models/IT_ADMIN/staff/staff_model.dart';
import 'package:qportal_webapp/models/IT_ADMIN/orgDirectory_model.dart';
import 'package:qportal_webapp/services/core_api.dart';
import 'package:qportal_webapp/utils/webApp_config.dart';
import 'package:qportal_webapp/utils/logger.dart';

class AdminApi {
  // ─── DASHBOARD & DIRECTORY ───────────────────────────────────────────────────

  // GET /getDashboardStats
  static Future<Map<String, dynamic>> getDashboardStats() async {
    logDebug('[AdminApi] getDashboardStats called');
    if (!await ApiCore.ensureConnection()) {
      logDebug('[AdminApi] getDashboardStats blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await ApiCore.client.get(
        Uri.parse('$kApiBaseUrl/getDashboardStats'),
      );
      if (res.statusCode != 200) {
        logDebug('[AdminApi] getDashboardStats failed: HTTP ${res.statusCode}');
        return {};
      }

      logDebug('[AdminApi] getDashboardStats success');
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      logDebug('[AdminApi] getDashboardStats exception: $e');
      throw ConnectionException();
    }
  }

  // GET /getDirectory
  static Future<List<OrgDirectoryRecord>> getOrgDirectory() async {
    logDebug('[AdminApi] getOrgDirectory called');
    if (!await ApiCore.ensureConnection()) {
      throw ConnectionException();
    }

    try {
      final res = await ApiCore.client.get(
        Uri.parse('$kApiBaseUrl/getDirectory'),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = body['directory'] as List? ?? [];
        return list.map((e) => OrgDirectoryRecord.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      logDebug('[AdminApi] getOrgDirectory exception: $e');
      throw ConnectionException();
    }
  }

  // ─── AUDIT LOGS ──────────────────────────────────────────────────────────────

  // GET /getAuditLogs
  static Future<List<LiveAuditLogRecord>> getAuditLogs({
    int page = 1,
    int limit = 25,
  }) async {
    logDebug('[AdminApi] getAuditLogs called (page: $page, limit: $limit)');
    if (!await ApiCore.ensureConnection()) {
      logDebug('[AdminApi] getAuditLogs blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await ApiCore.client.get(
        Uri.parse('$kApiBaseUrl/getAuditLogs?page=$page&limit=$limit'),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = body['records'] as List? ?? [];
        logDebug(
          '[AdminApi] getAuditLogs success: fetched ${list.length} records',
        );
        return list
            .map((e) => LiveAuditLogRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      logDebug('[AdminApi] getAuditLogs failed: HTTP ${res.statusCode}');
      return [];
    } catch (e) {
      logDebug('[AdminApi] getAuditLogs exception: $e');
      throw ConnectionException();
    }
  }

  // ─── STAFF MANAGEMENT ────────────────────────────────────────────────────────

  // GET /getStaff
  static Future<List<LiveStaffRecord>> getStaff() async {
    logDebug('[AdminApi] getStaff called');
    if (!await ApiCore.ensureConnection()) {
      logDebug('[AdminApi] getStaff blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await ApiCore.client.get(Uri.parse('$kApiBaseUrl/getStaff'));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = body['staff'] as List? ?? [];
        logDebug(
          '[AdminApi] getStaff success: fetched ${list.length} staff members',
        );
        return list
            .map((e) => LiveStaffRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      logDebug('[AdminApi] getStaff failed: HTTP ${res.statusCode}');
      return [];
    } catch (e) {
      logDebug('[AdminApi] getStaff exception: $e');
      throw ConnectionException();
    }
  }

  // POST /inviteStaff
  static Future<bool> inviteStaff({
    required String email,
    required PortalType portal,
    required String role,
  }) async {
    logDebug(
      '[AdminApi] inviteStaff called for email: $email, portal: ${portal.name}, role: $role',
    );
    if (!await ApiCore.ensureConnection()) {
      logDebug('[AdminApi] inviteStaff blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await ApiCore.client.post(
        Uri.parse('$kApiBaseUrl/inviteStaff'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'portal': portal.name, 'role': role}),
      );
      if (res.statusCode != 200) {
        logDebug('[AdminApi] inviteStaff failed: HTTP ${res.statusCode}');
        return false;
      }

      logDebug('[AdminApi] inviteStaff success');
      return true;
    } catch (e) {
      logDebug('[AdminApi] inviteStaff exception: $e');
      throw ConnectionException();
    }
  }

  // POST /updateStaffRole
  static Future<bool> updateStaffRole({
    required String id,
    required PortalType portal,
    required String role,
  }) async {
    logDebug(
      '[AdminApi] updateStaffRole called for staffID: $id, portal: ${portal.name}, role: $role',
    );
    if (!await ApiCore.ensureConnection()) {
      logDebug('[AdminApi] updateStaffRole blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await ApiCore.client.post(
        Uri.parse('$kApiBaseUrl/updateStaffRole'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id, 'portal': portal.name, 'role': role}),
      );
      if (res.statusCode != 200) {
        logDebug('[AdminApi] updateStaffRole failed: HTTP ${res.statusCode}');
        return false;
      }

      logDebug('[AdminApi] updateStaffRole success');
      return true;
    } catch (e) {
      logDebug('[AdminApi] updateStaffRole exception: $e');
      throw ConnectionException();
    }
  }

  // POST /deleteStaff
  static Future<bool> deleteStaff({
    required String id,
    required PortalType portal,
  }) async {
    logDebug(
      '[AdminApi] deleteStaff called for staffID: $id, portal: ${portal.name}',
    );
    if (!await ApiCore.ensureConnection()) {
      logDebug('[AdminApi] deleteStaff blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await ApiCore.client.post(
        Uri.parse('$kApiBaseUrl/deleteStaff'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id, 'portal': portal.name}),
      );
      if (res.statusCode != 200) {
        logDebug('[AdminApi] deleteStaff failed: HTTP ${res.statusCode}');
        return false;
      }

      logDebug('[AdminApi] deleteStaff success');
      return true;
    } catch (e) {
      logDebug('[AdminApi] deleteStaff exception: $e');
      throw ConnectionException();
    }
  }
}
