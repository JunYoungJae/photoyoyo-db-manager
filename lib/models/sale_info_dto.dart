import 'package:objectbox/objectbox.dart';

@Entity()
class SaleInfoDto {
  @Id(assignable: true)
  int id = 0;

  String saleNo;
  String saleId;
  String data;

  SaleInfoDto({required this.saleNo, required this.saleId, required this.data});
}
