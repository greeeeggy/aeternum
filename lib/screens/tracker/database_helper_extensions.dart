import 'package:menstrual_cycle_widget/database_helper/menstrual_cycle_db_helper.dart';
import 'package:menstrual_cycle_widget/menstrual_cycle_widget.dart';

extension MenstrualCycleDbHelperExtension on MenstrualCycleDbHelper {
  /// Clears ALL period logs for the current user
  Future<void> clearAllPeriodData() async {
    try {
      final db = await database;
      final customerId = MenstrualCycleWidget.instance!.getCustomerId();

      await db!.delete(
        MenstrualCycleDbHelper.tableUserPeriodsLogsData, // ← Qualified with class name
        where: '${MenstrualCycleDbHelper.columnCustomerId} = ?', // ← Qualified
        whereArgs: [customerId],
      );

      print('🗑️ All period logs cleared for user: $customerId');
    } catch (e) {
      print('🔥 Error clearing period data: $e');
      rethrow;
    }
  }
}