/// Contract §4 — API error classification (docs/API_CONTRACT.md).  
enum ApiErrorKind { network, auth, forbidden, notFound, validation, accounting, server }  
  
class ApiException implements Exception {  
  ApiException(this.kind, this.message, {this.statusCode, this.fieldErrors = const {}});  
  
  final ApiErrorKind kind;  
  final String message;  
  final int? statusCode;  
  final Map<String, List<String>> fieldErrors;  
  
  bool get hasFieldErrors => fieldErrors.isNotEmpty;  
  
  @override  
  String toString() => 'ApiException($kind, $statusCode): $message';  
}  
