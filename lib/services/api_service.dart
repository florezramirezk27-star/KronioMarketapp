import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../models/category.dart';

class ApiService {
  // Proxy de Vercel para evitar bloqueos de CORS; apunta al backend NestJS
  final String baseUrl = 'https://ecomerce-delta-three.vercel.app/api/proxy';

  Future<List<Product>> fetchProducts({
    String? search,
    String? categoryId,
    int page = 1,
    int limit = 50,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'limit': '$limit',
    };
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    if (categoryId != null && categoryId.isNotEmpty) {
      query['categoryId'] = categoryId;
    }

    final uri = Uri.parse('$baseUrl/products').replace(queryParameters: query);
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final body = _decodeBody(response.body);
      final List<dynamic> rawList;
      if (body is List) {
        rawList = body;
      } else if (body is Map && body['items'] is List) {
        rawList = body['items'] as List;
      } else if (body is Map && body['value'] is List) {
        rawList = body['value'] as List;
      } else {
        throw Exception('Formato de respuesta inesperado');
      }
      return rawList
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Error del servidor: ${response.statusCode}');
    }
  }

  Future<Product?> fetchProductBySlug(String slug) async {
    final response = await http.get(Uri.parse('$baseUrl/products/$slug'));
    if (response.statusCode == 200) {
      final body = _decodeBody(response.body);
      if (body is Map<String, dynamic>) {
        return Product.fromJson(body);
      }
    }
    return null;
  }

  Future<List<Category>> fetchCategories() async {
    final response = await http.get(Uri.parse('$baseUrl/categories'));
    if (response.statusCode == 200) {
      final body = _decodeBody(response.body);
      if (body is List) {
        return body
            .map((item) => Category.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }
    throw Exception('Error del servidor: ${response.statusCode}');
  }

  dynamic _decodeBody(String raw) => jsonDecode(raw);
}