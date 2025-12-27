class TaskLink {
  final int id;
  final int source;
  final int target;
  final String type; // '0': FS, '1': SS, '2': FF, '3': SF

  TaskLink({
    required this.id,
    required this.source,
    required this.target,
    required this.type,
  });

  factory TaskLink.fromJson(Map<String, dynamic> json) {
    return TaskLink(
      id: json['id'],
      source: json['source'],
      target: json['target'],
      type: json['type'].toString(),
    );
  }

  String get typeName {
    switch (type) {
      case '0':
        return '完成-开始 (FS)';
      case '1':
        return '开始-开始 (SS)';
      case '2':
        return '完成-完成 (FF)';
      case '3':
        return '开始-完成 (SF)';
      default:
        return '未知';
    }
  }

  String get typeShort {
    switch (type) {
      case '0':
        return 'FS';
      case '1':
        return 'SS';
      case '2':
        return 'FF';
      case '3':
        return 'SF';
      default:
        return '?';
    }
  }
}
