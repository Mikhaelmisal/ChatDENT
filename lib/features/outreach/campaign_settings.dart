import 'dart:convert';

/// WhatsApp / n8n campaign settings stored as JSON on [settingId].
class WhatsAppCampaign {
  static const settingId = 'wa_campaign____';
  static const flyerRecordId = 'wa_flyer_______';

  final String googleReviewUrl;
  final bool sendFlyerWithChat;
  final String flyerFile;
  final String openrouterModel;
  final String birthdayTemplate;
  final String reviewTemplate;
  final String marketingImageUrl;
  final String treatments;
  final int quietStart;
  final int quietEnd;

  const WhatsAppCampaign({
    this.googleReviewUrl = '',
    this.sendFlyerWithChat = true,
    this.flyerFile = '',
    this.openrouterModel = 'openai/gpt-4o-mini',
    this.birthdayTemplate =
        'Happy birthday {name}! The team at {clinic} wishes you a wonderful year. We would love to see you soon.',
    this.reviewTemplate =
        'Hi {name}, thank you for visiting {clinic}. If you were happy with your care, please leave us a Google review: {reviewUrl}',
    this.marketingImageUrl = '',
    this.treatments =
        'cleaning, filling, root canal, extraction, braces, aligners, implant, crown, denture, gum treatment, kids dentistry, whitening, x-ray',
    this.quietStart = 1260,
    this.quietEnd = 540,
  });

  factory WhatsAppCampaign.fromJsonString(String raw) {
    if (raw.trim().isEmpty) return const WhatsAppCampaign();
    try {
      return WhatsAppCampaign.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const WhatsAppCampaign();
    }
  }

  factory WhatsAppCampaign.fromJson(Map<String, dynamic> json) {
    const d = WhatsAppCampaign();
    return WhatsAppCampaign(
      googleReviewUrl: json['googleReviewUrl']?.toString() ?? '',
      sendFlyerWithChat: json['sendFlyerWithChat'] != false,
      flyerFile: json['flyerFile']?.toString() ?? '',
      openrouterModel:
          json['openrouterModel']?.toString() ?? d.openrouterModel,
      birthdayTemplate:
          json['birthdayTemplate']?.toString() ?? d.birthdayTemplate,
      reviewTemplate: json['reviewTemplate']?.toString() ?? d.reviewTemplate,
      marketingImageUrl: json['marketingImageUrl']?.toString() ?? '',
      treatments: json['treatments']?.toString() ?? d.treatments,
      quietStart: (json['quietStart'] as num?)?.toInt() ?? d.quietStart,
      quietEnd: (json['quietEnd'] as num?)?.toInt() ?? d.quietEnd,
    );
  }

  Map<String, dynamic> toJson() => {
        'googleReviewUrl': googleReviewUrl,
        'sendFlyerWithChat': sendFlyerWithChat,
        'flyerFile': flyerFile,
        'openrouterModel': openrouterModel,
        'birthdayTemplate': birthdayTemplate,
        'reviewTemplate': reviewTemplate,
        'marketingImageUrl': marketingImageUrl,
        'treatments': treatments,
        'quietStart': quietStart,
        'quietEnd': quietEnd,
      };

  String toJsonString() => jsonEncode(toJson());
}

/// Days until the next birthday, or null if only a birth year is stored.
int? daysUntilBirthday(DateTime birth, DateTime now) {
  if (birth.year < 1000) return null;
  var next = DateTime(now.year, birth.month, birth.day);
  if (DateTime(now.year, now.month, now.day).isAfter(next)) {
    next = DateTime(now.year + 1, birth.month, birth.day);
  }
  return DateTime(next.year, next.month, next.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
}
