class Reading {
  final double value;
  final String unit;

  Reading({required this.value, required this.unit});

  factory Reading.fromJson(Map<String, dynamic> json) {
    return Reading(
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String,
    );
  }
}

class DeviceControl {
  final String label;
  String state; // 'on' | 'off'

  DeviceControl({required this.label, required this.state});

  factory DeviceControl.fromJson(Map<String, dynamic> json) {
    return DeviceControl(
      label: json['label'] as String,
      state: json['state'] as String,
    );
  }

  bool get isOn => state == 'on';
}

class DeviceLocation {
  final String label;
  final double? lat;
  final double? lng;

  DeviceLocation({required this.label, this.lat, this.lng});

  factory DeviceLocation.fromJson(Map<String, dynamic> json) {
    return DeviceLocation(
      label: json['label'] as String? ?? '',
      lat: json['lat'] != null ? (json['lat'] as num).toDouble() : null,
      lng: json['lng'] != null ? (json['lng'] as num).toDouble() : null,
    );
  }

  bool get hasCoordinates => lat != null && lng != null;
}

class Equipment {
  final String id;
  final String name;
  final String type; // 'sensor' | 'relay' | 'valve'
  final bool online;
  final String? mqttUnid;
  final String? lastSeen;
  final String? onlineSince;
  final String? offlineSince;
  final DeviceLocation? location;
  final Map<String, Reading>? readings;
  final DeviceControl? control;
  final bool favorite;

  Equipment({
    required this.id,
    required this.name,
    required this.type,
    required this.online,
    this.mqttUnid,
    this.lastSeen,
    this.onlineSince,
    this.offlineSince,
    this.location,
    this.readings,
    this.control,
    this.favorite = false,
  });

  factory Equipment.fromJson(Map<String, dynamic> json) {
    Map<String, Reading>? readingsMap;
    if (json['readings'] != null) {
      readingsMap = (json['readings'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, Reading.fromJson(value)),
      );
    }

    return Equipment(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      online: json['online'] as bool? ?? false,
      mqttUnid: json['mqttUnid'] as String?,
      lastSeen: json['lastSeen'] as String?,
      onlineSince: json['onlineSince'] as String?,
      offlineSince: json['offlineSince'] as String?,
      location: json['location'] != null
          ? DeviceLocation.fromJson(json['location'])
          : null,
      readings: readingsMap,
      control: json['control'] != null
          ? DeviceControl.fromJson(json['control'])
          : null,
      favorite: json['favorite'] as bool? ?? false,
    );
  }

  Equipment copyWith({bool? favorite}) {
    return Equipment(
      id: id,
      name: name,
      type: type,
      online: online,
      mqttUnid: mqttUnid,
      lastSeen: lastSeen,
      onlineSince: onlineSince,
      offlineSince: offlineSince,
      location: location,
      readings: readings,
      control: control,
      favorite: favorite ?? this.favorite,
    );
  }
}

// سطر واحد في سجل قرايات العداد (Reports) - قراية فلو/سرعة/توتاليزر في وقت معين
class DeviceLogEntry {
  final DateTime? timestamp;
  final double flow;
  final double velocity;
  final double totalizer;

  DeviceLogEntry({
    required this.timestamp,
    required this.flow,
    required this.velocity,
    required this.totalizer,
  });

  factory DeviceLogEntry.fromJson(Map<String, dynamic> json) {
    return DeviceLogEntry(
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
      flow: (json['flow'] as num?)?.toDouble() ?? 0,
      velocity: (json['velocity'] as num?)?.toDouble() ?? 0,
      totalizer: (json['totalizer'] as num?)?.toDouble() ?? 0,
    );
  }
}
