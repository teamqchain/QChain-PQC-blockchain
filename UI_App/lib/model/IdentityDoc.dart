import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qwallet_mobileapp/constants/colors.dart';

class IdentityDoc {
  final String id;
  final String title;
  final String subtitle;
  final String issued;
  final String expires;
  final String number;
  final Color cardColor;
  final IconData icon;
  final String category;
  bool isFavourite;

  IdentityDoc({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.issued,
    required this.expires,
    required this.number,
    required this.cardColor,
    required this.icon,
    required this.category,
    this.isFavourite = false,
  });
}


// ─── ALL DOCUMENTS ────────────────────────────────────────────────────────────

final List<IdentityDoc> allDocs = [
  IdentityDoc(
    id: '1',
    title: 'Emirates ID',
    subtitle: 'Federal Authority for Identity',
    issued: '15 Jan 2023',
    expires: '14 Jan 2028',
    number: '784-1990-1234567-8',
    cardColor: qAzureBlue,
    icon: Icons.badge,
    category: 'identity',
    isFavourite: true,
  ),
  IdentityDoc(
    id: '2',
    title: 'UAE Residence Visa',
    subtitle: 'General Directorate of Residency',
    issued: '20 Mar 2023',
    expires: '19 Mar 2026',
    number: 'A/11/2023/1234567',
    cardColor: qLeafGreen,
    icon: Icons.description,
    category: 'identity',
    isFavourite: false,
  ),
  IdentityDoc(
    id: '3',
    title: 'Passport',
    subtitle: 'Ministry of Interior',
    issued: '05 Jun 2019',
    expires: '04 Jun 2029',
    number: 'A12345678',
    cardColor: qMagentaPink,
    icon: Icons.menu_book,
    category: 'identity',
    isFavourite: false,
  ),
  IdentityDoc(
    id: '4',
    title: 'Bachelor of Science',
    subtitle: 'University of Sharjah',
    issued: '15 Jun 2020',
    expires: '15 Jun 2030',
    number: 'UOS-2020-12345',
    cardColor: qAmethyst,
    icon: Icons.school,
    category: 'education',
    isFavourite: false,
  ),
  IdentityDoc(
    id: '5',
    title: 'IELTS Certificate',
    subtitle: 'British Council',
    issued: '10 Aug 2021',
    expires: '10 Aug 2026',
    number: 'BC-2021-98765',
    cardColor: qSlateBlue,
    icon: Icons.description,
    category: 'education',
    isFavourite: false,
  ),
  IdentityDoc(
    id: '6',
    title: 'Health Insurance',
    subtitle: 'DAMAN',
    issued: '01 Jan 2023',
    expires: '31 Dec 2024',
    number: 'DMN-2023-54321',
    cardColor: qCherryRed,
    icon: Icons.local_hospital,
    category: 'medical',
    isFavourite: false,
  ),
  IdentityDoc(
    id: '7',
    title: 'Medical Certificate',
    subtitle: 'UHS',
    issued: '01 Jan 2023',
    expires: '31 Dec 2024',
    number: 'DMN-2023-54321',
    cardColor: qVibrantIndigo,
    icon: Icons.local_hospital,
    category: 'medical',
    isFavourite: false,
  ),

  IdentityDoc(
    id: '8',
    title: 'New car§d 8',
    subtitle: 'Federal Authority for Identity',
    issued: '15 Jan 2023',
    expires: '14 Jan 2028',
    number: '784-1990-1234567-8',
    cardColor: qAzureBlue,
    icon: Icons.badge,
    category: 'identity',
    isFavourite: true,
  ),
  IdentityDoc(
    id: '9',
    title: 'new card 9',
    subtitle: 'General Directorate of Residency',
    issued: '20 Mar 2023',
    expires: '19 Mar 2026',
    number: 'A/11/2023/1234567',
    cardColor: qLeafGreen,
    icon: Icons.description,
    category: 'identity',
    isFavourite: false,
  ),
  IdentityDoc(
    id: '10',
    title: 'New card 10',
    subtitle: 'Ministry of Interior',
    issued: '05 Jun 2019',
    expires: '04 Jun 2029',
    number: 'A12345678',
    cardColor: qMagentaPink,
    icon: Icons.menu_book,
    category: 'identity',
    isFavourite: false,
  ),
];
