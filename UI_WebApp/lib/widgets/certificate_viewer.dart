import 'package:flutter/material.dart';
import 'package:qchain_shared/certificate_template.dart';
import 'package:qchain_shared/certificate_viewer.dart';

/// QPortal certificate preview.
/// Thin wrapper over the shared fixed-A4 [CertificateSheet].
class CertificateViewer extends StatelessWidget {
  final CertificateData data;
  final bool showWatermark;
  final double? maxWidth;

  const CertificateViewer({
    super.key,
    required this.data,
    this.showWatermark = true,
    this.maxWidth = CertificateSheet.designWidth,
  });

  @override
  Widget build(BuildContext context) {
    return CertificateSheet(
      data: data,
      showWatermark: showWatermark,
      maxWidth: maxWidth,
    );
  }
}
