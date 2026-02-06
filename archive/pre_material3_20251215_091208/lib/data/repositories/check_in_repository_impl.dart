import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/check_in/check_in_status.dart';
import 'package:dabbler/data/models/check_in/check_in_log.dart';
import 'package:dabbler/data/repositories/base_repository.dart';
import 'package:dabbler/data/repositories/check_in_repository.dart';

class CheckInRepositoryImpl extends BaseRepository
    implements CheckInRepository {
  CheckInRepositoryImpl(super.svc);

  static const String _checkInsTable = 'user_check_ins';
  static const String _logsTable = 'check_in_logs';

  @override
  Future<Result<CheckInResponse, Failure>> performCheckIn({
    Map<String, dynamic>? deviceInfo,
  }) async {
    final uid = svc.authUserId();
    if (uid == null) {
      return Err(AuthFailure(message: 'Not signed in'));
    }

    return guard(() async {
      debugPrint('CheckInRepository: Performing check-in for user $uid');
      debugPrint('CheckInRepository: Device info: $deviceInfo');
      debugPrint('CheckInRepository: Calling Supabase RPC: perform_check_in');

      // Call the Supabase perform_check_in function
      final response = await svc.client.rpc(
        'perform_check_in',
        params: {'p_user_id': uid, 'p_device_info': deviceInfo},
      );

      debugPrint('CheckInRepository: perform_check_in response=$response');
      debugPrint('CheckInRepository: Response type: ${response.runtimeType}');

      // Response is an array with a single row
      if (response is List && response.isNotEmpty) {
        final data = response.first as Map<String, dynamic>;
        debugPrint('CheckInRepository: Parsed response data=$data');
        debugPrint(
          'CheckInRepository: total_days_completed=${data['total_days_completed']}',
        );
        debugPrint(
          'CheckInRepository: is_first_check_in_today=${data['is_first_check_in_today']}',
        );
        return CheckInResponse.fromJson(data);
      }

      debugPrint('CheckInRepository: ERROR - Invalid response format');
      debugPrint('CheckInRepository: Response was: $response');
      throw Exception(
        'Invalid response from perform_check_in: Expected non-empty List, got ${response.runtimeType}',
      );
    });
  }

  @override
  Future<Result<CheckInStatusDetail, Failure>> getCheckInStatus() async {
    final uid = svc.authUserId();
    if (uid == null) {
      return Err(AuthFailure(message: 'Not signed in'));
    }

    return guard(() async {
      debugPrint('CheckInRepository: Getting status for user $uid');

      // Call the Supabase get_check_in_status function
      final response = await svc.client.rpc(
        'get_check_in_status',
        params: {'p_user_id': uid},
      );

      debugPrint(
        'CheckInRepository: Response type=${response.runtimeType}, data=$response',
      );

      // Response is an array with a single row or empty
      if (response is List) {
        if (response.isEmpty) {
          // User has never checked in
          debugPrint(
            'CheckInRepository: No check-in data found, returning defaults',
          );
          return const CheckInStatusDetail(
            streakCount: 0,
            totalDaysCompleted: 0,
            isCompleted: false,
            lastCheckIn: null,
            checkedInToday: false,
            daysRemaining: 14,
          );
        }

        final data = response.first as Map<String, dynamic>;
        debugPrint('CheckInRepository: Parsing data=$data');
        return CheckInStatusDetail.fromJson(data);
      }

      throw Exception('Invalid response from get_check_in_status');
    });
  }

  @override
  Future<Result<CheckInStatus?, Failure>> getCheckInRecord() async {
    final uid = svc.authUserId();
    if (uid == null) {
      return Err(AuthFailure(message: 'Not signed in'));
    }

    return guard(() async {
      final response = await svc.client
          .from(_checkInsTable)
          .select()
          .eq('user_id', uid)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return CheckInStatus.fromJson(Map<String, dynamic>.from(response));
    });
  }

  @override
  Future<Result<List<CheckInLog>, Failure>> getCheckInLogs({int? limit}) async {
    final uid = svc.authUserId();
    if (uid == null) {
      return Err(AuthFailure(message: 'Not signed in'));
    }

    return guard(() async {
      var query = svc.client
          .from(_logsTable)
          .select()
          .eq('user_id', uid)
          .order('check_in_date', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;

      return (response as List)
          .map((json) => CheckInLog.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    });
  }

  @override
  Stream<Result<CheckInStatus?, Failure>> watchCheckInStatus() {
    final uid = svc.authUserId();
    if (uid == null) {
      return Stream.value(Err(AuthFailure(message: 'Not signed in')));
    }

    return svc.client
        .from(_checkInsTable)
        .stream(primaryKey: ['user_id'])
        .eq('user_id', uid)
        .map<Result<CheckInStatus?, Failure>>((rows) {
          if (rows.isEmpty) {
            return const Ok(null);
          }

          final data = rows.first;
          try {
            final status = CheckInStatus.fromJson(
              Map<String, dynamic>.from(data),
            );
            return Ok<CheckInStatus?, Failure>(status);
          } catch (e) {
            return Err(
              DataFailure(message: 'Failed to parse check-in status: $e'),
            );
          }
        })
        .handleError((error) {
          return Err<CheckInStatus?, Failure>(
            DataFailure(message: 'Stream error: $error'),
          );
        });
  }
}
