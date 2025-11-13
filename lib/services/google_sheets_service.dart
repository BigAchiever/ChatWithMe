import 'dart:convert';
import 'package:dio/dio.dart';

class GoogleSheetService {
  final String sheetCsvUrl;

  GoogleSheetService(this.sheetCsvUrl);

  final Dio _dio = Dio();

  Future<List<Map<String, String>>> fetchEmployees() async {
    final response = await _dio.get(sheetCsvUrl);

    final lines = const LineSplitter().convert(response.data);
    final headers = lines.first.split(',');

    List<Map<String, String>> employees = [];

    for (int i = 1; i < lines.length; i++) {
      final values = lines[i].split(',');

      Map<String, String> row = {};
      for (int j = 0; j < headers.length; j++) {
        row[headers[j]] = j < values.length ? values[j] : '';
      }

      employees.add(row);
    }

    return employees;
  }

  Future<Map<String, String>?> searchEmployee(String name) async {
    final allEmployees = await fetchEmployees();

    for (var emp in allEmployees) {
      if (emp["Employee Name"]?.trim().toLowerCase() ==
          name.trim().toLowerCase()) {
        return emp;
      }
    }

    return null;
  }
}
