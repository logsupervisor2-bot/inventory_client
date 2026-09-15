import 'package:dio/dio.dart';  
  
import 'api_exception.dart';  
  
/// Contract §4 — decodes 401/403/404/422-A/B/C/D/5xx/network into ApiException.  
ApiException mapDioError(DioException e) {  
  final res = e.response;  
  final status = res?.statusCode;  
  
  if (res == null || status == null) {  
    return ApiException(ApiErrorKind.network, 'Network error: ${e.message ?? e.type.name}');  
  }  
  
  final body = res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : null;  
  String? messageOf() =>  
      body != null && body['message'] is String ? body['message'] as String : null;  
  
  switch (status) {  
    case 401:  
      return ApiException(ApiErrorKind.auth, messageOf() ?? 'Unauthenticated.', statusCode: 401);  
    case 403:  
      return ApiException(ApiErrorKind.forbidden, messageOf() ?? 'Forbidden.', statusCode: 403);  
    case 404:  
      return ApiException(ApiErrorKind.notFound, messageOf() ?? 'Not found.', statusCode: 404);  
    case 422:  
      // §4 422-C: {success:false, error}  
      if (body?['success'] == false && body?['error'] is String) {  
        return ApiException(ApiErrorKind.accounting, body!['error'] as String, statusCode: 422);  
      }  
      final errors = _extractErrors(body);  
      // §4 422-D: errors.ledger = GLOBAL accounting failure, not a field error  
      if (errors.containsKey('ledger')) {  
        return ApiException(ApiErrorKind.accounting, errors['ledger']!.join('; '), statusCode: 422);  
      }  
      if (errors.isNotEmpty) {  
        return ApiException(ApiErrorKind.validation, messageOf() ?? errors.values.first.first,  
            statusCode: 422, fieldErrors: errors);  
      }  
      return ApiException(ApiErrorKind.validation, messageOf() ?? 'Validation failed.', statusCode: 422);  
    default:  
      return ApiException(ApiErrorKind.server, messageOf() ?? 'Server error ($status).', statusCode: status);  
  }  
}  
  
/// 422-A: {message, errors:{field:[...]}} · 422-B: bare {field:[...]}  
Map<String, List<String>> _extractErrors(Map<String, dynamic>? body) {  
  if (body == null) return {};  
  
  final raw = body['errors'];  
  if (raw is Map<String, dynamic>) {  
    final out = <String, List<String>>{};  
    raw.forEach((k, v) {  
      if (v is List) out[k] = v.map((e) => e.toString()).toList();  
      if (v is String) out[k] = [v];  
    });  
    return out;  
  }  
  
  const reserved = {'message', 'success', 'error', 'data'};  
  final out = <String, List<String>>{};  
  body.forEach((k, v) {  
    if (reserved.contains(k)) return;  
    if (v is List && v.isNotEmpty && v.every((e) => e is String)) out[k] = v.cast<String>();  
  });  
  return out;  
}  
