import 'package:dio/dio.dart';  
import 'package:test/test.dart';  
  
import 'package:inventory_client/core/errors/api_error_mapper.dart';  
import 'package:inventory_client/core/errors/api_exception.dart';  
  
DioException err(int? status, Object? body) => DioException(  
      requestOptions: RequestOptions(path: '/x'),  
      response: status == null  
          ? null  
          : Response(requestOptions: RequestOptions(path: '/x'), statusCode: status, data: body),  
    );  
  
void main() {  
  group('contract §4 error matrix', () {  
    test('401 → auth', () {  
      final e = mapDioError(err(401, {'message': 'Unauthenticated.'}));  
      expect(e.kind, ApiErrorKind.auth);  
      expect(e.message, 'Unauthenticated.');  
    });  
  
    test('403 → forbidden', () {  
      final e = mapDioError(err(403, {'message': 'User has no company assigned.'}));  
      expect(e.kind, ApiErrorKind.forbidden);  
    });  
  
    test('404 → notFound', () {  
      expect(mapDioError(err(404, {'message': 'Product not found'})).kind, ApiErrorKind.notFound);  
    });  
  
    test('422-A → validation with fields', () {  
      final e = mapDioError(err(422, {  
        'message': 'The given data was invalid.',  
        'errors': {'supplier_code': ['The supplier code has already been taken.']},  
      }));  
      expect(e.kind, ApiErrorKind.validation);  
      expect(e.fieldErrors['supplier_code'], isNotEmpty);  
    });  
  
    test('422-B → bare errors body', () {  
      final e = mapDioError(err(422, {'name': ['The name field is required.']}));  
      expect(e.kind, ApiErrorKind.validation);  
      expect(e.fieldErrors.containsKey('name'), isTrue);  
    });  
  
    test('422-C → accounting', () {  
      final e = mapDioError(err(422, {'success': false, 'error': 'Trial balance generation failed.'}));  
      expect(e.kind, ApiErrorKind.accounting);  
    });  
  
    test('422-D ledger → accounting (global)', () {  
      final e = mapDioError(err(422, {  
        'message': 'The given data was invalid.',  
        'errors': {'ledger': ['Cash account 1000 is missing.']},  
      }));  
      expect(e.kind, ApiErrorKind.accounting);  
      expect(e.hasFieldErrors, isFalse);  
    });  
  
    test('500 → server', () {  
      expect(mapDioError(err(500, null)).kind, ApiErrorKind.server);  
    });  
  
    test('network → network', () {  
      final e = mapDioError(DioException(  
        requestOptions: RequestOptions(path: '/x'),  
        type: DioExceptionType.connectionError,  
      ));  
      expect(e.kind, ApiErrorKind.network);  
    });  
  });  
}  
