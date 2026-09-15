/// Contract §5 — raw user model (GET /user, inside login/register E1).  
class User {  
  const User({required this.id, required this.name, required this.email});  
  
  final int id;  
  final String name;  
  final String email;  
  
  factory User.fromJson(Map<String, dynamic> json) => User(  
        id: (json['id'] as num).toInt(),  
        name: json['name']?.toString() ?? '',  
        email: json['email']?.toString() ?? '',  
      );  
  
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};  
}  
