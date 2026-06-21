import 'package:flutter/material.dart';
import 'package:qportal_webapp/models/holder_model.dart';
import 'package:qportal_webapp/models/ISSUER/schema_model.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/utils/dateFormatter.dart';

class CredentialPreviewCard extends StatelessWidget {
  final SchemaRecord schema;
  final HolderRecord holder;
  final Map<String, String> fieldValues;
  final DateTime? expiryDate;
  final bool noExpiry;
  final String orgName;
  final String issuerName;

  const CredentialPreviewCard({super.key, 
    required this.schema,
    required this.holder,
    required this.fieldValues,
    required this.expiryDate,
    required this.noExpiry,
    required this.orgName,
    required this.issuerName,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF091525),
                const Color(0xFF0C1D38),
                AppColors.issuingAccent.withOpacity(0.07),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.issuingAccent.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.issuingAccent.withOpacity(0.09),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.issuingAccent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.account_balance,
                      size: 18,
                      color: AppColors.issuingAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          orgName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Verifiable Credential',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.issuingAccent.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.verified,
                    size: 17,
                    color: AppColors.issuingAccent,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 1,
                color: AppColors.issuingAccent.withOpacity(0.18),
              ),
              const SizedBox(height: 14),
              Text(
                schema.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Issued to: ${holder.fullName}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.65),
                ),
              ),
              const SizedBox(height: 14),
              ...schema.fields.map((f) {
                final val = fieldValues[f.id] ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(
                          f.label,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.45),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          val.isEmpty ? '—' : val,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              Container(
                height: 1,
                color: AppColors.issuingAccent.withOpacity(0.14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Issue Date',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.white.withOpacity(0.38),
                          ),
                        ),
                        Text(
                          DateFormatter.formatIsoDate(DateTime.now().toIso8601String()),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expiry',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.white.withOpacity(0.38),
                          ),
                        ),
                        Text(
                          noExpiry
                              ? 'No Expiry'
                              : expiryDate != null
                              ? DateFormatter.formatIsoDate(expiryDate! as String?)
                              : '—',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Signed with Dilithium (CRYSTALS-Dilithium3)',
                style: TextStyle(
                  fontSize: 9,
                  color: AppColors.issuingAccent.withOpacity(0.55),
                ),
              ),
            ],
          ),
        ),
        // PREVIEW watermark
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Transform.rotate(
                angle: -0.4,
                child: Text(
                  'PREVIEW',
                  style: TextStyle(
                    fontSize: 54,
                    fontWeight: FontWeight.w900,
                    color: Colors.white.withOpacity(0.045),
                    letterSpacing: 8,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
