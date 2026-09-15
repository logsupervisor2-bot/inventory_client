import 'user.dart';  
  
/// Contract §5 — POST /login & /register → E1 {user, token}  
class LoginResponse {  
  const LoginResponse({required this.user, required this.token});  
  
  final User user;  
  final String token;  
  
  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(  
        user: User.fromJson(json['user'] as Map<String, dynamic>),  
        token: json['token'] as String,  
      );  
}  
