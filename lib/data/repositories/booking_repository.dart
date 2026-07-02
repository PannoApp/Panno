import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../models/api_booking.dart';
import '../models/booking_request.dart';
import '../paginated_response.dart';
import '../services/api_client.dart';

class BookingRepository {
  BookingRepository({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  final Dio _dio;
  static const _uuid = Uuid();

  Future<void> createBooking(BookingRequest req) async {
    await _dio.post<Map<String, dynamic>>(
      '/bookings/',
      data: req.toJson(),
      options: Options(
        headers: {'Idempotency-Key': _uuid.v4()},
      ),
    );
  }

  Future<List<ApiBooking>> fetchHistory({int page = 1}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/bookings/',
      queryParameters: {'page': page},
    );
    return PaginatedResponse.parse(
      response.data ?? {},
      ApiBooking.fromJson,
    ).results;
  }
}
