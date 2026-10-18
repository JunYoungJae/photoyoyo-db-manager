import 'package:objectbox/objectbox.dart';

// Generated from the original Photo YoYo objectbox-model.json.
// Preserve field names and types; do not use a newly generated model against production without validation.

@Entity()
class FrameDto {
  @Id(assignable: true)
  int id = 0;
  String frameId = '';
  String frameCode = '';
  String updatedAt = '';
  String fId = '';
  String name = '';
  String path = '';
  String transparents = '';
  double width = 0.0;
  double height = 0.0;
  String categoryCode = '';
}

@Entity()
class KioskDto {
  @Id(assignable: true)
  int id = 0;
  String kioskId = '';
  String kioskName = '';
  String kioskType = '';
  String hostname = '';
  int status = 0;
}

@Entity()
class SiteDto {
  @Id(assignable: true)
  int id = 0;
  String siteId = '';
  String siteCode = '';
  String siteName = '';
  int qrServiceYn = 0;
}

@Entity()
class AdditionalPriceDto {
  @Id(assignable: true)
  int id = 0;
  String priceCode = '';
  String priceName = '';
  int price = 0;
  int prints = 0;
  int sort = 0;
}

@Entity()
class AppBackgroundDto {
  @Id(assignable: true)
  int id = 0;
  String updateAt = '';
  String cfgKey = '';
  String path = '';
}

@Entity()
class BackgroundDto {
  @Id(assignable: true)
  int id = 0;
  String backgroundId = '';
  String frameId = '';
  String path = '';
  String fromDate = '';
  String toDate = '';
  String updatedAt = '';
}

@Entity()
class FrameCategoryDto {
  @Id(assignable: true)
  int id = 0;
  String categoryCode = '';
  String categoryName = '';
  String backgroundName = '';
  String bgId = '';
}

@Entity()
class FrameCutDto {
  @Id(assignable: true)
  int id = 0;
  String frameCutId = '';
  String frameId = '';
  String isDefault = '';
  int priceVi = 0;
  int priceEn = 0;
  int priceKr = 0;
  int quantity = 0;
  String couponYn = '';
}

@Entity()
class PriceDto {
  @Id(assignable: true)
  int id = 0;
  String priceCode = '';
  String priceName = '';
  double price = 0.0;
  int prints = 0;
  int sort = 0;
}

@Entity()
class SettingDto {
  @Id(assignable: true)
  int id = 0;
  String settingId = '';
  String updatedAt = '';
  String cfgKey = '';
  String cfgTitle = '';
  int cusNum = 0;
}

@Entity()
class ZipFileDto {
  @Id(assignable: true)
  int id = 0;
  String zipId = '';
  String zipPath = '';
  String zipRawImagePath = '';
}
