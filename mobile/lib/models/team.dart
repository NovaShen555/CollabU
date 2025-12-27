class Team {
  final int id;
  final String name;
  final String? description;
  final String? avatar;
  final int creatorId;
  final String? createdAt;
  final String? inviteCode;

  Team({
    required this.id,
    required this.name,
    this.description,
    this.avatar,
    required this.creatorId,
    this.createdAt,
    this.inviteCode,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      avatar: json['avatar'],
      creatorId: json['creator_id'],
      createdAt: json['created_at'],
      inviteCode: json['invite_code'],
    );
  }
}
