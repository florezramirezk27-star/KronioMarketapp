import 'package:flutter/material.dart';

import '../models/product.dart';
import '../screens/product_detail_screen.dart';
import '../services/api_exception.dart';
import 'product_card.dart';

/// Resultados de busqueda con su propio estado.
///
/// La vista es la duena del estado de la busqueda y recibe la funcion de red
/// como callback. Asi no hace falta que la pantalla padre comparta estado con
/// la vista por fuera.
///
/// Los errores se muestran con el mensaje que devuelve la capa de red (que ya
/// viene en espanol y listo para el usuario). Antes se pintaba
/// `Text('Error: ${snapshot.error}')`, o sea el string crudo de la excepcion.
class SearchResultsView extends StatefulWidget {
  const SearchResultsView({
    super.key,
    required this.onSearch,
    this.onProductTap,
  });

  /// Ejecuta la busqueda. Debe lanzar [ApiException] con `message` en espanol,
  /// o cualquier otra excepcion si hay un fallo no previsto.
  final Future<List<Product>> Function(String query) onSearch;

  final void Function(Product product)? onProductTap;

  @override
  State<SearchResultsView> createState() => _SearchResultsViewState();
}

class _SearchResultsViewState extends State<SearchResultsView> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Product> _results = const [];
  bool _loading = false;
  String? _error;
  bool _hasSearched = false;
  String _lastQuery = '';

  /// Secuencia de peticiones: ignora la respuesta si llego una busqueda mas
  /// reciente. Evita que una peticion lenta overwrite los resultados nuevos.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_controller.text.trim().isEmpty && _hasSearched) {
      setState(() {
        _results = const [];
        _hasSearched = false;
        _error = null;
        _loading = false;
      });
    }
    // Refresca el boton de limpiar sin llamar a setState innecesariamente.
    setState(() {});
  }

  Future<void> _submit() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    final requestId = ++_requestId;
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _error = null;
      _hasSearched = true;
      _lastQuery = query;
    });

    try {
      final results = await widget.onSearch(query);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = 'Ocurrio un error inesperado al buscar.';
        _loading = false;
      });
    }
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _results = const [];
      _hasSearched = false;
      _error = null;
    });
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchField(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar productos...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Limpiar',
                  onPressed: _clear,
                ),
        ),
        onSubmitted: (_) => _submit(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _SearchErrorView(message: _error!, onRetry: _submit);
    }

    if (!_hasSearched) {
      return const _SearchPromptView();
    }

    if (_results.isEmpty) {
      return _SearchEmptyView(query: _lastQuery, onClear: _clear);
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.68,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final product = _results[index];
        return ProductCard(
          product: product,
          onTap: widget.onProductTap == null
              ? () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(product: product),
                    ),
                  )
              : () => widget.onProductTap!(product),
        );
      },
    );
  }
}

class _SearchPromptView extends StatelessWidget {
  const _SearchPromptView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 56, color: Colors.grey),
          SizedBox(height: 12),
          Text('Escribe para buscar productos'),
        ],
      ),
    );
  }
}

class _SearchEmptyView extends StatelessWidget {
  const _SearchEmptyView({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'Sin resultados para "$query"',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onClear,
              child: const Text('Buscar otra cosa'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchErrorView extends StatelessWidget {
  const _SearchErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
