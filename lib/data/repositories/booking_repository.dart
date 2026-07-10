import 'package:dio/dio.dart';
import '../models/api_booking.dart';
import '../models/availability_slot.dart';
import '../models/booking_request.dart';
import '../models/booking_zone.dart';
import '../models/json_utils.dart';
import '../paginated_response.dart';
import '../services/api_client.dart';

class BookingRepository {
  BookingRepository({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  final Dio _dio;

  Future<void> createBooking(
    BookingRequest req, {
    required String idempotencyKey,
  }) async {
    // Получаем Idempotency-Key извне, чтобы он сохранялся при сетевых повторах (retries)
    await _dio.post<Map<String, dynamic>>(
      '/bookings/',
      data: req.toJson(),
      options: Options(
        headers: {'Idempotency-Key': idempotencyKey},
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

  Future<List<AvailabilitySlot>> fetchAvailability({
    required String date,
    required int guests,
    int? zoneId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/bookings/availability/',
      queryParameters: {
        'date': date,
        'guests': guests,
        if (zoneId != null) 'zone_id': zoneId,
      },
    );
    return asJsonMapList(response.data?['slots'])
        .map(AvailabilitySlot.fromJson)
        .toList();
  }

  Future<List<BookingZone>> fetchZones() async {
    final response = await _dio.get<List<dynamic>>('/bookings/zones/');
    return (response.data ?? const [])
        .map((e) => BookingZone.fromJson(asJsonMap(e)))
        .toList();
  }
}
