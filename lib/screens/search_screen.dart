import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/search_results_view.dart';

/// Pantalla de busqueda.
///
/// Es una envoltura minima: toda la logica (estado, resultados, errores,
/// reintento) vive en [SearchResultsView], que recibe la funcion de red.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiService _api = ApiService();

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar')),
      body: SearchResultsView(
        // Los `ApiException` se propagan: la vista muestra `e.message`.
        onSearch: (query) async {
          final result = await _api.fetchProducts(search: query);
          return result.items;
        },
      ),
    );
  }
}
