import 'json_utils.dart';
import 'interior_slide.dart';

class SocialLink {
  const SocialLink({required this.label, required this.url});

  final String label;
  final String url;

  factory SocialLink.fromJson(Map<String, dynamic> json) {
    return SocialLink(
      label: parseString(json['label'], field: 'label'),
      url: parseString(json['url'], field: 'url'),
    );
  }

  Map<String, dynamic> toJson() => {'label': label, 'url': url};
}

class VisitRuleItem {
  const VisitRuleItem({required this.title, required this.body});

  final String title;
  final String body;

  factory VisitRuleItem.fromJson(Map<String, dynamic> json) {
    return VisitRuleItem(
      title: parseString(json['title'], field: 'title'),
      body: parseString(json['body'], field: 'body'),
    );
  }

  Map<String, dynamic> toJson() => {'title': title, 'body': body};
}

List<SocialLink> _parseSocialLinks(Map<String, dynamic> json) {
  final raw = json['social_links'] ?? json['socialLinks'];
  if (raw is List && raw.isNotEmpty) {
    return asJsonMapList(raw).map(SocialLink.fromJson).toList(growable: false);
  }
  final links = <SocialLink>[];
  void add(String label, dynamic value) {
    final url = parseStringOrNull(value);
    if (url != null) links.add(SocialLink(label: label, url: url));
  }

  add('WhatsApp', json['whatsapp']);
  add('Telegram', json['telegram']);
  add('Instagram', json['instagram']);
  return links;
}

List<VisitRuleItem> _parseVisitRules(dynamic raw) {
  if (raw == null) return const [];
  if (raw is String) {
    final text = raw.trim();
    if (text.isEmpty) return const [];
    return [VisitRuleItem(title: 'Правила', body: text)];
  }
  if (raw is List) {
    return asJsonMapList(raw).map(VisitRuleItem.fromJson).toList(growable: false);
  }
  return const [];
}

List<InteriorSlide> _parseHeroSlides(dynamic raw) {
  if (raw == null) return const [];
  if (raw is! List) return const [];
  return raw
      .map((e) => InteriorSlide.fromHeroJson(asJsonMap(e)))
      .toList(growable: false);
}

class CoreInfo {
  const CoreInfo({
    required this.address,
    required this.workingHours,
    this.workingHoursNote,
    required this.isOpenNow,
    required this.phone,
    required this.socialLinks,
    required this.heroSlides,
    required this.bookingDepositRequired,
    this.bookingDepositNote,
    required this.visitRules,
    required this.privacyPolicy,
    this.conceptDescription,
    this.twogisLink,
    this.googleMapsLink,
    this.yandexMapsLink,
    this.feedbackUrl,
    this.termsOfService,
    this.tourLink,
  });

  final String address;
  final String workingHours;
  final String? workingHoursNote;
  final bool isOpenNow;
  final String phone;
  final List<SocialLink> socialLinks;
  final List<InteriorSlide> heroSlides;
  final bool bookingDepositRequired;
  final String? bookingDepositNote;
  final List<VisitRuleItem> visitRules;
  final String privacyPolicy;
  final String? conceptDescription;
  final String? twogisLink;
  final String? googleMapsLink;
  final String? yandexMapsLink;
  final String? feedbackUrl;
  final String? termsOfService;
  final String? tourLink;

  List<String> get heroImageUrls => heroSlides
      .map((s) => s.imageUrl)
      .where((url) => url.isNotEmpty)
      .toList(growable: false);

  factory CoreInfo.fromJson(Map<String, dynamic> json) {
    return CoreInfo(
      address: parseString(json['address'], field: 'address'),
      workingHours: parseString(
        json['working_hours'] ?? json['workingHours'],
        field: 'working_hours',
      ),
      workingHoursNote: parseStringOrNull(
        json['working_hours_note'] ?? json['workingHoursNote'],
      ),
      isOpenNow: parseBool(json['is_open_now'] ?? json['isOpenNow']),
      phone: parseString(json['phone'], field: 'phone'),
      socialLinks: _parseSocialLinks(json),
      heroSlides: _parseHeroSlides(json['hero_slides'] ?? json['heroSlides']),
      bookingDepositRequired: parseBool(
        json['booking_deposit_required'] ?? json['bookingDepositRequired'],
      ),
      bookingDepositNote: parseStringOrNull(
        json['booking_deposit_note'] ?? json['bookingDepositNote'],
      ),
      visitRules: _parseVisitRules(json['visit_rules'] ?? json['visitRules']),
      privacyPolicy: parseString(
        json['privacy_policy'] ?? json['privacyPolicy'],
        field: 'privacy_policy',
      ),
      conceptDescription: parseStringOrNull(
        json['concept_description'] ?? json['conceptDescription'],
      ),
      twogisLink: parseStringOrNull(json['twogis_link'] ?? json['twogisLink']),
      googleMapsLink: parseStringOrNull(
        json['google_maps_link'] ?? json['googleMapsLink'],
      ),
      yandexMapsLink: parseStringOrNull(
        json['yandex_maps_link'] ?? json['yandexMapsLink'],
      ),
      feedbackUrl: parseStringOrNull(json['feedback_url'] ?? json['feedbackUrl']),
      termsOfService: parseStringOrNull(
        json['terms_of_service'] ?? json['termsOfService'],
      ),
      tourLink: parseStringOrNull(json['tour_link'] ?? json['tourLink']),
    );
  }

  Map<String, dynamic> toJson() => {
        'address': address,
        'working_hours': workingHours,
        if (workingHoursNote != null) 'working_hours_note': workingHoursNote,
        'is_open_now': isOpenNow,
        'phone': phone,
        'social_links': socialLinks.map((e) => e.toJson()).toList(),
        'hero_slides': heroSlides.map((e) => e.toJson()).toList(),
        'booking_deposit_required': bookingDepositRequired,
        if (bookingDepositNote != null) 'booking_deposit_note': bookingDepositNote,
        'visit_rules': visitRules.map((e) => e.toJson()).toList(),
        'privacy_policy': privacyPolicy,
        if (conceptDescription != null) 'concept_description': conceptDescription,
        if (twogisLink != null) 'twogis_link': twogisLink,
        if (googleMapsLink != null) 'google_maps_link': googleMapsLink,
        if (yandexMapsLink != null) 'yandex_maps_link': yandexMapsLink,
        if (feedbackUrl != null) 'feedback_url': feedbackUrl,
        if (termsOfService != null) 'terms_of_service': termsOfService,
        if (tourLink != null) 'tour_link': tourLink,
      };
}
