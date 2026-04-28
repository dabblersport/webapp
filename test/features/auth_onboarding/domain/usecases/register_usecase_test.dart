import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/auth_onboarding/domain/usecases/register_usecase.dart';
import '../../../../helpers/mock_factories.dart';

void main() {
  late MockAuthRepository mockRepo;
  late RegisterUseCase useCase;

  setUp(() {
    mockRepo = MockAuthRepository();
    useCase = RegisterUseCase(mockRepo);
  });

  group('RegisterUseCase', () {
    group('input validation', () {
      test('returns AuthFailure when email is empty', () async {
        final result = await useCase(
          RegisterParams(email: '', password: 'password123'),
        );

        expect(result.isFailure, true);
        expect(result.requireError, isA<AuthFailure>());
        expect(
          result.requireError.message,
          'Email and password must not be empty',
        );
        verifyZeroInteractions(mockRepo);
      });

      test('returns AuthFailure when password is empty', () async {
        final result = await useCase(
          RegisterParams(email: 'user@example.com', password: ''),
        );

        expect(result.isFailure, true);
        expect(result.requireError, isA<AuthFailure>());
        expect(
          result.requireError.message,
          'Email and password must not be empty',
        );
        verifyZeroInteractions(mockRepo);
      });

      test('returns AuthFailure when both email and password are empty',
          () async {
        final result = await useCase(
          RegisterParams(email: '', password: ''),
        );

        expect(result.isFailure, true);
        expect(result.requireError, isA<AuthFailure>());
        verifyZeroInteractions(mockRepo);
      });
    });

    group('delegation to repository', () {
      test('calls repo.signUp with correct credentials on valid input',
          () async {
        final session = makeAuthSession();
        when(
          mockRepo.signUp(
            email: 'user@example.com',
            password: 'password123',
          ),
        ).thenAnswer((_) async => Ok(session));

        final result = await useCase(
          RegisterParams(email: 'user@example.com', password: 'password123'),
        );

        expect(result.isSuccess, true);
        expect(result.requireValue, session);
        verify(
          mockRepo.signUp(
            email: 'user@example.com',
            password: 'password123',
          ),
        ).called(1);
      });

      test('forwards NetworkFailure from repo unchanged', () async {
        when(
          mockRepo.signUp(
            email: anyNamed('email'),
            password: anyNamed('password'),
          ),
        ).thenAnswer(
          (_) async => Err(const NetworkFailure(message: 'No connection')),
        );

        final result = await useCase(
          RegisterParams(email: 'user@example.com', password: 'password123'),
        );

        expect(result.isFailure, true);
        expect(result.requireError, isA<NetworkFailure>());
      });

      test('forwards ServerFailure from repo unchanged', () async {
        when(
          mockRepo.signUp(
            email: anyNamed('email'),
            password: anyNamed('password'),
          ),
        ).thenAnswer(
          (_) async => Err(const ServerFailure(message: 'Internal error')),
        );

        final result = await useCase(
          RegisterParams(email: 'user@example.com', password: 'password123'),
        );

        expect(result.isFailure, true);
        expect(result.requireError, isA<ServerFailure>());
      });
    });
  });
}
