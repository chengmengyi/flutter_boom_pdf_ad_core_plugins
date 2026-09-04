enum AdType { appOpen, interstitial, native, rewarded, banner }

extension AdTypeX on AdType {
  String get rawValue {
    switch (this) {
      case AdType.appOpen:
        return 'open';
      case AdType.interstitial:
        return 'int';
      case AdType.native:
        return 'nat';
      case AdType.rewarded:
        return 'rv';
      case AdType.banner:
        return 'ban';
    }
  }

  bool get isFullScreen =>
      this == AdType.appOpen ||
      this == AdType.interstitial ||
      this == AdType.rewarded;

  bool get isInlineView => this == AdType.banner || this == AdType.native;

  static AdType? tryParse(String? rawValue) {
    switch (rawValue) {
      case 'open':
        return AdType.appOpen;
      case 'int':
        return AdType.interstitial;
      case 'nat':
        return AdType.native;
      case 'rv':
      case 'raw':
      case 'rwd':
        return AdType.rewarded;
      case 'ban':
        return AdType.banner;
      default:
        return null;
    }
  }
}
