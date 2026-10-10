import 'package:invoiso/models/stock_movement.dart';

abstract class StockMovementRepository {
  Future<StockMovement> recordMovement({
    required StockMovement movement,
    bool updateProductStock,
    bool allowNegative,
  });
  Future<List<StockMovement>> getMovementsForProduct(
    String productId, {
    int? limit,
    int offset,
  });
  Future<List<StockMovement>> getMovementsPage({
    required int offset,
    required int limit,
    String? productId,
    String? movementType,
    String? fromDate,
    String? toDate,
  });
  Future<int> getMovementsCount({
    String? productId,
    String? movementType,
    String? fromDate,
    String? toDate,
  });
  Future<Map<String, double>> getStockSummary({
    String? fromDate,
    String? toDate,
  });
}
