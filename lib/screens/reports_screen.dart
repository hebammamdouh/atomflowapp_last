import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/dashboard_pdf.dart';

// نطاقات الفترة الزمنية لتقرير الداشبورد
enum _RangeOption { today, week, month }

extension on _RangeOption {
  String get label {
    switch (this) {
      case _RangeOption.today:
        return 'Today';
      case _RangeOption.week:
        return '7 Days';
      case _RangeOption.month:
        return '30 Days';
    }
  }

  int get days {
    switch (this) {
      case _RangeOption.today:
        return 1;
      case _RangeOption.week:
        return 7;
      case _RangeOption.month:
        return 30;
    }
  }

  int get logLimit {
    switch (this) {
      case _RangeOption.today:
        return 300;
      case _RangeOption.week:
        return 1000;
      case _RangeOption.month:
        return 2000;
    }
  }
}

// شاشة "Reports" - تقرير PDF شامل عن حالة الأجهزة والترندات، منفصلة تمامًا
// عن شاشة "Logs" (سجل القرايات التفصيلي) - كل واحدة عنصر مستقل في السايدبار
class ReportsScreen extends StatefulWidget {
  final VoidCallback onMenuTap;
  const ReportsScreen({super.key, required this.onMenuTap});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _RangeOption _dashboardRange = _RangeOption.week;
  bool _isGeneratingPdf = false;

  // بتجيب كل الأجهزة + سجل قرايات كل عداد في المدى المختار، وتبني منها تقرير
  // PDF فيه حالة النظام + إحصائيات وسباركلاين كل عداد + لوجو الشركة، وتفتح
  // شاشة المشاركة/الحفظ بتاعة النظام (بتشتغل على الموبايل والويب والديسكتوب)
  Future<void> _downloadDashboardPdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final devices = await ApiService.getEquipment();
      final sensors = devices.where((d) => d.type == 'sensor').toList();
      final cutoff = DateTime.now().subtract(Duration(days: _dashboardRange.days));

      final stats = <DeviceReportStat>[];
      for (final device in sensors) {
        final logs = await ApiService.getDeviceLogs(
          device.id,
          limit: _dashboardRange.logLimit,
        );
        final inRange = logs
            .where((l) => l.timestamp != null && l.timestamp!.isAfter(cutoff))
            .toList();
        stats.add(DeviceReportStat(
          device: device,
          logs: inRange.isNotEmpty ? inRange : logs,
        ));
      }

      final onlineCount = devices.where((d) => d.online).length;
      final bytes = await buildDashboardReportPdf(
        stats: stats,
        rangeLabel: _dashboardRange.label,
        onlineCount: onlineCount,
        totalCount: devices.length,
      );

      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'atom_flow_dashboard_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate the PDF report')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            child: _dashboardReportCard(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(bottom: BorderSide(color: AppColors.borderGrey)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.menu_rounded, color: AppColors.textDark),
              onPressed: widget.onMenuTap,
            ),
            Text(
              'Reports',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark),
            ),
          ],
        ),
      ),
    );
  }

  // كارت "Dashboard Report" - اختيار المدى الزمني وتنزيل تقرير PDF شامل
  // (حالة الأجهزة + إحصائيات وترند كل عداد + لوجو الشركة) بدل ما تفتحي
  // التطبيق كل مرة
  Widget _dashboardReportCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.picture_as_pdf_rounded,
                  size: 18, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Text(
                'Dashboard Report',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'System status and meter trends as a downloadable PDF',
            style: TextStyle(fontSize: 11.5, color: AppColors.textGrey),
          ),
          const SizedBox(height: 12),
          Row(
            children: _RangeOption.values.map((option) {
              final selected = _dashboardRange == option;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _isGeneratingPdf
                        ? null
                        : () => setState(() => _dashboardRange = option),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primaryBlue
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppColors.primaryBlue
                              : AppColors.borderGrey,
                        ),
                      ),
                      child: Text(
                        option.label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isGeneratingPdf ? null : _downloadDashboardPdf,
              icon: _isGeneratingPdf
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download_rounded, size: 16),
              label: Text(_isGeneratingPdf ? 'Generating…' : 'Download PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
