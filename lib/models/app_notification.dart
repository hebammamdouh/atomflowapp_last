// models/app_notification.dart
// نوتفيكيشن واحدة زي ما بترجع من /api/notifications - بتتولد من الباك اند تلقائي
// (أونلاين/أوفلاين + فلو high/low + توتال عدى عتبة معينة)
class AppNotification {
  final String id;
  final String type; // device_online | device_offline | flow_high | flow_low | total_threshold
  final String? deviceId;
  final String? deviceName;
  final String message;
  final double? value;
  final double? threshold;
  final DateTime? createdAt;
  final bool read;

  AppNotification({
    required this.id,
    required this.type,
    this.deviceId,
    this.deviceName,
    required this.message,
    this.value,
    this.threshold,
    this.createdAt,
    this.read = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: json['type'] as String? ?? '',
      deviceId: json['deviceId'] as String?,
      deviceName: json['deviceName'] as String?,
      message: json['message'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble(),
      threshold: (json['threshold'] as num?)?.toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      read: json['read'] as bool? ?? false,
    );
  }

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      type: type,
      deviceId: deviceId,
      deviceName: deviceName,
      message: message,
      value: value,
      threshold: threshold,
      createdAt: createdAt,
      read: read ?? this.read,
    );
  }
}
