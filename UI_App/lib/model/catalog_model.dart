import 'package:flutter/material.dart';

class CatalogCategory {
  final String name;
  final List<CatalogIssuer> issuers;

  CatalogCategory({required this.name, required this.issuers});

  factory CatalogCategory.fromJson(Map<String, dynamic> json) {
    return CatalogCategory(
      name: json['name'] ?? 'General',
      issuers:
          (json['issuers'] as List<dynamic>?)
              ?.map((i) => CatalogIssuer.fromJson(i))
              .toList() ??
          [],
    );
  }

  IconData get icon {
    final n = name.toLowerCase();
    if (n.contains('government')) return Icons.gavel;
    if (n.contains('health') || n.contains('medical'))
      return Icons.local_hospital;
    if (n.contains('education')) return Icons.school;
    if (n.contains('bank') || n.contains('finance'))
      return Icons.account_balance;
    if (n.contains('travel')) return Icons.flight;
    return Icons.business;
  }
}

class CatalogIssuer {
  final String id;
  final String name;
  final List<CatalogService> services;

  CatalogIssuer({required this.id, required this.name, required this.services});

  factory CatalogIssuer.fromJson(Map<String, dynamic> json) {
    return CatalogIssuer(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Organization',
      services:
          (json['services'] as List<dynamic>?)
              ?.map((s) => CatalogService.fromJson(s))
              .toList() ??
          [],
    );
  }

  Color get color {
    final n = name.toLowerCase();
    if (n.contains('health') || n.contains('hospital'))
      return const Color(0xFF1A2A4A);
    if (n.contains('university')) return const Color(0xFF3A1A4A);
    if (n.contains('bank')) return const Color(0xFF1A4A3A);
    return const Color(0xFF111111);
  }
}

class CatalogService {
  final String id;
  final String name;
  final String description;

  CatalogService({
    required this.id,
    required this.name,
    required this.description,
  });

  factory CatalogService.fromJson(Map<String, dynamic> json) {
    return CatalogService(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Document',
      description: json['description'] ?? 'Official verifiable credential',
    );
  }
}
