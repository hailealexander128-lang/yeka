import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/submission_model.dart';

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api/mobile';
    }
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return 'http://10.0.2.2:5000/api/mobile';
      }
    } catch (_) {}
    return 'http://localhost:5000/api/mobile';
  } 

  Future<UserModel?> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        return UserModel.fromJson(jsonDecode(response.body));
      }
      print('Login failed: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getWeredas() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/weredas'));
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      print('Get Weredas error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMahberats() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/mahberats'));
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      print('Get Mahberats error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCompanies() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/companies'));
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      print('Get Companies error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getVehicles() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/vehicles'));
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      print('Get Vehicles error: $e');
      return [];
    }
  }

  Future<bool> submitWork(SubmissionModel submission) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/submit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(submission.toJson()),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Submit error (saving offline): $e');
      return false;
    }
  }

  Future<String?> uploadImage(dynamic imageFile) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload-image'));
      
      if (imageFile is String) {
        // File path
        request.files.add(await http.MultipartFile.fromPath('file', imageFile));
      } else {
        // XFile - read bytes
        final bytes = await imageFile.readAsBytes();
        final fileName = imageFile.name ?? 'image.jpg';
        request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Return full URL with base
        final serverBase = baseUrl.replaceAll('/api/mobile', '');
        return '$serverBase${data['url']}';
      }
      print('Upload failed: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Upload image error: $e');
      return null;
    }
  }

  Future<List<SubmissionModel>> getHistory(int userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/history/$userId'));
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((json) {
          json['userId'] = 0;
          json['role'] = '';
          json['weredaId'] = 0;
          json['mahberatId'] = 0;
          json['rate'] = 0.0;
          return SubmissionModel.fromJson(json);
        }).toList();
      }
      return [];
    } catch (e) {
      print('Get history error: $e');
      return [];
    }
  }

  Future<List<SubmissionModel>> getPendingSubmissions() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/pending'));
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((json) {
          // Add dummy fields required by model if not returned
          json['userId'] = 0;
          json['role'] = '';
          json['weredaId'] = 0;
          json['mahberatId'] = 0;
          json['rate'] = 0.0;
          return SubmissionModel.fromJson(json);
        }).toList();
      }
      return [];
    } catch (e) {
      print('Get pending error: $e');
      return [];
    }
  }

  Future<bool> updateSubmissionStatus(int id, String status) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/submissions/$id/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': status}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Update status error: $e');
      return false;
    }
  }
}
