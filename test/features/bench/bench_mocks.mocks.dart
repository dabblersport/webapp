// Mocks for dabbler/test/features/bench/bench_mocks.dart, in the shape
// Mockito 5.4.6 generates for @GenerateNiceMocks([MockSpec<BenchRepository>()]).
//
// KAN-706: written by hand. `dart run build_runner build -d` aborts on this
// SDK ("Missing implementation of visitDotShorthandPropertyAccess" from the
// analyzer build_runner pins) before mockito runs. Regenerate from
// bench_mocks.dart once the toolchain can, and this file is replaced.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i3;

import 'package:dabbler/core/fp/failure.dart' as _i5;
import 'package:dabbler/core/fp/result.dart' as _i2;
import 'package:dabbler/features/bench/data/bench_repository.dart' as _i4;
import 'package:dabbler/features/bench/data/bench_status.dart' as _i6;
import 'package:mockito/mockito.dart' as _i1;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: deprecated_member_use
// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: must_be_immutable
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class

class _FakeResult_0<T, E> extends _i1.SmartFake implements _i2.Result<T, E> {
  _FakeResult_0(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

/// A class which mocks [BenchRepository].
class MockBenchRepository extends _i1.Mock implements _i4.BenchRepository {
  @override
  _i3.Future<_i2.Result<_i6.BenchStatus, _i5.Failure>> load() =>
      (super.noSuchMethod(
            Invocation.method(#load, []),
            returnValue:
                _i3.Future<_i2.Result<_i6.BenchStatus, _i5.Failure>>.value(
                  _FakeResult_0<_i6.BenchStatus, _i5.Failure>(
                    this,
                    Invocation.method(#load, []),
                  ),
                ),
            returnValueForMissingStub:
                _i3.Future<_i2.Result<_i6.BenchStatus, _i5.Failure>>.value(
                  _FakeResult_0<_i6.BenchStatus, _i5.Failure>(
                    this,
                    Invocation.method(#load, []),
                  ),
                ),
          )
          as _i3.Future<_i2.Result<_i6.BenchStatus, _i5.Failure>>);

  @override
  _i3.Future<_i2.Result<_i2.Unit, _i5.Failure>> save(
    _i6.BenchSettings? settings,
  ) =>
      (super.noSuchMethod(
            Invocation.method(#save, [settings]),
            returnValue: _i3.Future<_i2.Result<_i2.Unit, _i5.Failure>>.value(
              _FakeResult_0<_i2.Unit, _i5.Failure>(
                this,
                Invocation.method(#save, [settings]),
              ),
            ),
            returnValueForMissingStub:
                _i3.Future<_i2.Result<_i2.Unit, _i5.Failure>>.value(
                  _FakeResult_0<_i2.Unit, _i5.Failure>(
                    this,
                    Invocation.method(#save, [settings]),
                  ),
                ),
          )
          as _i3.Future<_i2.Result<_i2.Unit, _i5.Failure>>);

  @override
  _i3.Future<_i2.Result<_i2.Unit, _i5.Failure>> end() =>
      (super.noSuchMethod(
            Invocation.method(#end, []),
            returnValue: _i3.Future<_i2.Result<_i2.Unit, _i5.Failure>>.value(
              _FakeResult_0<_i2.Unit, _i5.Failure>(
                this,
                Invocation.method(#end, []),
              ),
            ),
            returnValueForMissingStub:
                _i3.Future<_i2.Result<_i2.Unit, _i5.Failure>>.value(
                  _FakeResult_0<_i2.Unit, _i5.Failure>(
                    this,
                    Invocation.method(#end, []),
                  ),
                ),
          )
          as _i3.Future<_i2.Result<_i2.Unit, _i5.Failure>>);
}
