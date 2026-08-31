import 'package:file_cast/domain/models/requisition.dart';

abstract interface class RequisitionRepository {
  Future<List<Requisition>> getRequisitions();
}
