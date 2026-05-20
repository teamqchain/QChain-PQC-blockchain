import 'package:flutter/material.dart';

// ─── MODELS ───────────────────────────────────────────────────────────────────

class Credential {
  final int id;
  final String type, name, issuer, issued, expiry,status;
  final IconData icon;
  final Color color;

  const Credential({
    required this.id,
    required this.type,
    required this.name,
    required this.issuer,
    required this.issued,
    required this.expiry,
    required this.status,
    required this.icon,
    required this.color,
  });
}

class ActivityItem {
  final String text, time;
  final Color color;
  final IconData icons;

  const ActivityItem({
    required this.icons,
    required this.text,
    required this.time,
    required this.color,
  });
}

// ─── DUMMY DATA ───────────────────────────────────────────────────────────────

const List<Credential> dummyCredentials = [
  Credential(
    id: 1,
    type: 'Government',
    name: 'Emirates ID',
    issuer: 'Federal Authority',
    issued: 'Jan 2023',
    expiry: 'Jan 2026',
    status: 'Valid',
    icon: Icons.badge,
    color: Color(0xFF1A4A3A),
  ),
  Credential(
    id: 2,
    type: 'Health',
    name: 'COVID-19 Vaccination Record',
    issuer: 'Ministry of Health UAE',
    issued: 'Feb 2022',
    expiry: 'Jan 2024',
    status: 'Suspended',
    icon: Icons.local_hospital,
    color: Color(0xFF1A2A4A),
  ),
  Credential(
    id: 3,
    type: 'Academic',
    name: 'Bachelor of Computer Science',
    issuer: 'University of Sharjah',
    issued: 'Jun 2024',
    expiry: 'Jan 2026',
    status: 'Valid',
    icon: Icons.school,
    color: Color(0xFF3A1A4A),
  ),
  Credential(
    id: 4,
    type: 'Professional',
    name: 'AWS Cloud Practitioner',
    issuer: 'Amazon Web Services',
    issued: 'Mar 2024',
    expiry: 'Jan 2026',
    status: 'Revoked',
    icon: Icons.work,
    color: Color(0xFF1A3A5C),
  ),
  Credential(
    id: 5,
    type: 'Government',
    name: 'Driving License',
    issuer: 'Road Transport Authority',
    issued: 'Mar 2024',
    expiry: 'Jan 2026',
    status: 'Expired',
    icon: Icons.drive_eta,
    color: Color(0xFF1A3A5C),
  ),
];

const List<ActivityItem> dummyActivity = [
  ActivityItem(
    icons: Icons.download,
    text: 'Credential received from University of Sharjah',
    time: '2 days ago',
    color: Color(0xFF0D9488),
  ),
  ActivityItem(
    icons: Icons.upload,
    text: 'Credential presented to ABC Company',
    time: '5 hours ago',
    color: Color(0xFF3B82F6),
  ),
  ActivityItem(
    icons: Icons.refresh,
    text: 'Credential status refreshed',
    time: '1 hour ago',
    color: Color(0xFF8B5CF6),
  ),
  ActivityItem(
    icons: Icons.verified_user,
    text: 'Emirates ID verified on blockchain',
    time: '3 days ago',
    color: Color(0xFF0D9488),
  ),
];
