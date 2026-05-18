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

class CoreInfo {
  const CoreInfo({
    required this.address,
    required this.workingHours,
    required this.isOpenNow,
    required this.phone,
    required this.socialLinks,
    required this.heroSlides,
    this.heroVideoUrl,
    required this.bookingDepositRequired,
    required this.visitRules,
    required this.privacyPolicy,
  });

  final String address;
  final String workingHours;
  final bool isOpenNow;
  final String phone;
  final List<SocialLink> socialLinks;
  final List<InteriorSlide> heroSlides;
  final String? heroVideoUrl;
  final bool bookingDepositRequired;
  final List<VisitRuleItem> visitRules;
  final String privacyPolicy;

  factory CoreInfo.fromJson(Map<String, dynamic> json) {
    return CoreInfo(
      address: parseString(json['address'], field: 'address'),
      workingHours: parseString(
        json['working_hours'] ?? json['workingHours'],
        field: 'working_hours',
      ),
      isOpenNow: parseBool(json['is_open_now'] ?? json['isOpenNow']),
      phone: parseString(json['phone'], field: 'phone'),
      socialLinks: asJsonMapList(json['social_links'] ?? json['socialLinks'])
          .map(SocialLink.fromJson)
          .toList(growable: false),
      heroSlides: asJsonMapList(json['hero_slides'] ?? json['heroSlides'])
          .map(InteriorSlide.fromJson)
          .toList(growable: false),
      heroVideoUrl: parseStringOrNull(json['hero_video_url'] ?? json['heroVideoUrl']),
      bookingDepositRequired: parseBool(
        json['booking_deposit_required'] ?? json['bookingDepositRequired'],
      ),
      visitRules: asJsonMapList(json['visit_rules'] ?? json['visitRules'])
          .map(VisitRuleItem.fromJson)
          .toList(growable: false),
      privacyPolicy: parseString(
        json['privacy_policy'] ?? json['privacyPolicy'],
        field: 'privacy_policy',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'address': address,
        'working_hours': workingHours,
        'is_open_now': isOpenNow,
        'phone': phone,
        'social_links': socialLinks.map((e) => e.toJson()).toList(),
        'hero_slides': heroSlides.map((e) => e.toJson()).toList(),
        if (heroVideoUrl != null) 'hero_video_url': heroVideoUrl,
        'booking_deposit_required': bookingDepositRequired,
        'visit_rules': visitRules.map((e) => e.toJson()).toList(),
        'privacy_policy': privacyPolicy,
      };
}
