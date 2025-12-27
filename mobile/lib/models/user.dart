class User {
  final int id;
  final String username;
  final String email;
  final String? studentId;
  final String? nickname;
  final String? avatar;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.studentId,
    this.nickname,
    this.avatar,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'] ?? 'Unknown User',
      email: json['email'] ?? 'No Email',
      studentId: json['student_id'],
      nickname: json['nickname'],
      avatar: json['avatar'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'student_id': studentId,
      'nickname': nickname,
      'avatar': avatar,
    };
  }
}
