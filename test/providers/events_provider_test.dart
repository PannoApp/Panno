import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piligrim/data/events_news_data.dart';
import 'package:piligrim/data/models/api_event.dart';
import 'package:piligrim/data/models/api_event_photo.dart';
import 'package:piligrim/data/repositories/events_repository.dart';
import 'package:piligrim/providers/events_provider.dart';

class _MockEventsRepository extends Mock implements EventsRepository {}

ApiEvent _sampleEvent({int id = 1, bool isPast = false}) => ApiEvent(
      id: id,
      title: 'Вечер',
      description: 'Описание',
      startsAt: DateTime.utc(2026, 6, 15, 19),
      format: ApiEventFormat.open,
      isPast: isPast,
    );

void main() {
  group('EventsProvider', () {
    late _MockEventsRepository repository;

    setUp(() {
      repository = _MockEventsRepository();
    });

    test('loadUpcoming sets list on success', () async {
      when(() => repository.fetchUpcoming())
          .thenAnswer((_) async => [_sampleEvent()]);

      final provider = EventsProvider(repository: repository);
      await provider.loadUpcoming();

      expect(provider.upcoming, hasLength(1));
      expect(provider.usedMockFallback, isFalse);
      expect(provider.upcomingError, isNull);
    });

    test('loadUpcoming falls back to mocks on error', () async {
      when(() => repository.fetchUpcoming()).thenThrow(Exception('offline'));

      final provider = EventsProvider(repository: repository);
      await provider.loadUpcoming();

      expect(provider.upcoming, isNotEmpty);
      expect(provider.usedMockFallback, isTrue);
    });

    test('reserveEvent calls repository', () async {
      when(() => repository.createReservation(eventId: 3, guestsCount: 2))
          .thenAnswer((_) async {});

      final provider = EventsProvider(repository: repository);
      await provider.reserveEvent(3, 2);

      verify(() => repository.createReservation(eventId: 3, guestsCount: 2))
          .called(1);
      expect(provider.reserveError, isNull);
    });

    test('reserveEvent sets reserveError on failure', () async {
      when(() => repository.createReservation(eventId: 1, guestsCount: 1))
          .thenThrow(Exception('conflict'));

      final provider = EventsProvider(repository: repository);
      await expectLater(
        provider.reserveEvent(1, 1),
        throwsA(isA<Exception>()),
      );
      expect(provider.reserveError, isNotNull);
    });

    test('loadNews uses mock posts when API fails', () async {
      when(() => repository.fetchNews()).thenThrow(Exception('fail'));

      final provider = EventsProvider(repository: repository);
      await provider.loadNews();

      expect(provider.news.length, mockNewsPosts().length);
    });

    test('loadPhotoReport sets photoReport on success', () async {
      final photos = [
        const ApiEventPhoto(id: 1, imageUrl: 'https://cdn/r1.jpg', order: 0),
        const ApiEventPhoto(id: 2, imageUrl: 'https://cdn/r2.jpg', order: 1),
      ];
      when(() => repository.fetchPhotoReport(5)).thenAnswer((_) async => photos);

      final provider = EventsProvider(repository: repository);
      await provider.loadPhotoReport(5);

      expect(provider.photoReport, hasLength(2));
      expect(provider.photoReport.first.imageUrl, 'https://cdn/r1.jpg');
      expect(provider.isLoadingPhotoReport, isFalse);
    });

    test('loadPhotoReport sets empty list on network error', () async {
      when(() => repository.fetchPhotoReport(any())).thenThrow(Exception('offline'));

      final provider = EventsProvider(repository: repository);
      await provider.loadPhotoReport(1);

      expect(provider.photoReport, isEmpty);
      expect(provider.isLoadingPhotoReport, isFalse);
    });

    test('loadPhotoReport flips isLoadingPhotoReport during fetch', () async {
      when(() => repository.fetchPhotoReport(any()))
          .thenAnswer((_) async => <ApiEventPhoto>[]);

      final provider = EventsProvider(repository: repository);
      final loadFuture = provider.loadPhotoReport(1);

      expect(provider.isLoadingPhotoReport, isTrue);
      await loadFuture;
      expect(provider.isLoadingPhotoReport, isFalse);
    });
  });
}
