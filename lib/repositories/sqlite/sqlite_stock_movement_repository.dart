import 'package:invoiso/database/stock_movement_service.dart';
import 'package:invoiso/models/stock_movement.dart';
import 'package:invoiso/repositories/stock_movement_repository.dart';

class SqliteStockMovementRepository implements StockMovementRepository {
  @override
  Future<StockMovement> recordMovement({
    required StockMovement movement,
    bool updateProductStock = true,
    bool allowNegative = false,
  }) =>
      StockMovementService.recordMovement(
        movement: movement,
        updateProductStock: updateProductStock,
        allowNegative: allowNegative,
      );

  @override
  Future<List<StockMovement>> getMovementsForProduct(
    String productId, {
    int? limit,
    int offset = 0,
  }) =>
      StockMovementService.getMovementsForProduct(
        productId,
        limit: limit,
        offset: offset,
      );

  @override
  Future<List<StockMovement>> getMovementsPage({
    required int offset,
    required int limit,
    String? productId,
    String? movementType,
    String? fromDate,
    String? toDate,
  }) =>
      StockMovementService.getMovementsPage(
        offset: offset,
        limit: limit,
        productId: productId,
        movementType: movementType,
        fromDate: fromDate,
        toDate: toDate,
      );

  @override
  Future<int> getMovementsCount({
    String? productId,
    String? movementType,
    String? fromDate,
    String? toDate,
  }) =>
      StockMovementService.getMovementsCount(
        productId: productId,
        movementType: movementType,
        fromDate: fromDate,
        toDate: toDate,
      );

  @override
  Future<Map<String, double>> getStockSummary({
    String? fromDate,
    String? toDate,
  }) =>
      StockMovementService.getStockSummary(
        fromDate: fromDate,
        toDate: toDate,
      );
}
