class UserProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? picture;
  final String role;

  UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.picture,
    this.role = 'USER',
  });

  String get fullName => '$firstName $lastName'.trim();

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      firstName: json['first_name'] ?? json['given_name'] ?? json['name'] ?? '',
      lastName: json['last_name'] ?? json['family_name'] ?? '',
      email: json['email'] ?? '',
      picture: json['picture'],
      role: json['role'] ?? 'USER',
    );
  }
}

class UserSearchResult {
  final String id;
  final String firstName;
  final String lastName;
  final String email;

  UserSearchResult({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
    );
  }
}
