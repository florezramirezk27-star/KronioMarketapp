import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import '../widgets/brand_logo.dart';
import '../widgets/cart_scope.dart';
import '../widgets/product_card.dart';
import 'cart_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  late Future<List<Product>> _productsFuture;
  late Future<List<Category>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _productsFuture = _api.fetchProducts();
    _categoriesFuture = _api.fetchCategories();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              BrandLogo(size: 32),
              SizedBox(width: 8),
              Text('Kronio Market'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
            ),
            const _CartButton(),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Inicio'),
              Tab(text: 'Catálogo'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _HomeTab(
              productsFuture: _productsFuture,
              categoriesFuture: _categoriesFuture,
              onSearch: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
            ),
            _CatalogTab(
              productsFuture: _productsFuture,
              categoriesFuture: _categoriesFuture,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  final Future<List<Product>> productsFuture;
  final Future<List<Category>> categoriesFuture;
  final VoidCallback onSearch;

  const _HomeTab({
    required this.productsFuture,
    required this.categoriesFuture,
    required this.onSearch,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Category>>(
      future: widget.categoriesFuture,
      builder: (context, catSnapshot) {
        final categories = catSnapshot.data ?? const <Category>[];
        return RefreshIndicator(
          onRefresh: () async {
            // Re-emitir la solicitud a los Future
            setState(() {});
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _Banner(
                title: '¡Bienvenido a Kronio!',
                subtitle: 'Los mejores productos con descuentos',
                onAction: widget.onSearch,
              ),
              const SizedBox(height: 24),
              _SectionTitle(
                title: 'Categorías',
                trailing: categories.isNotEmpty
                    ? '${categories.length} disponibles'
                    : null,
              ),
              const SizedBox(height: 12),
              _CategoriesStrip(categories: categories),
              const SizedBox(height: 24),
              const _SectionTitle(title: 'Productos destacados'),
              const SizedBox(height: 12),
              FutureBuilder<List<Product>>(
                future: widget.productsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return _ErrorBox(onRetry: () => setState(() {}));
                  }
                  final products = snapshot.data ?? const <Product>[];
                  if (products.isEmpty) {
                    return const Text('No hay productos disponibles');
                  }
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.68,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) =>
                        ProductCard(product: products[index]),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CatalogTab extends StatefulWidget {
  final Future<List<Product>> productsFuture;
  final Future<List<Category>> categoriesFuture;

  const _CatalogTab({
    required this.productsFuture,
    required this.categoriesFuture,
  });

  @override
  State<_CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<_CatalogTab> {
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Category>>(
      future: widget.categoriesFuture,
      builder: (context, catSnapshot) {
        final categories = catSnapshot.data ?? const <Category>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: Colors.grey.shade600),
                      const SizedBox(width: 10),
                      Text(
                        'Buscar productos...',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _CategoryChip(
                    label: 'Todos',
                    selected: _selectedCategoryId == null,
                    onTap: () => setState(() => _selectedCategoryId = null),
                  ),
                  ...categories.map(
                    (c) => _CategoryChip(
                      label: c.name,
                      selected: _selectedCategoryId == c.id,
                      onTap: () =>
                          setState(() => _selectedCategoryId = c.id),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<Product>>(
                future: _selectedCategoryId == null
                    ? widget.productsFuture
                    : ApiService()
                        .fetchProducts(categoryId: _selectedCategoryId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}',
                          textAlign: TextAlign.center),
                    );
                  }
                  final products = snapshot.data ?? const <Product>[];
                  if (products.isEmpty) {
                    return const Center(
                        child: Text('No se encontraron productos'));
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.68,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) =>
                        ProductCard(product: products[index]),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _controller = TextEditingController();
  List<Product> _results = const [];
  bool _loading = false;
  String? _error;
  bool _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = const [];
        _searched = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
    });
    try {
      final results =
          await _api.fetchProducts(search: query.trim(), limit: 50);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Buscar productos...',
            border: InputBorder.none,
          ),
          onSubmitted: _search,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _search(_controller.text),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }
    if (_searched && _results.isEmpty) {
      return const Center(child: Text('Sin resultados para esa búsqueda'));
    }
    if (!_searched) {
      return const Center(
        child: Text('Escribe y presiona buscar'),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.68,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _results.length,
      itemBuilder: (context, index) => ProductCard(product: _results[index]),
    );
  }
}

class _Banner extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onAction;

  const _Banner({
    required this.title,
    required this.subtitle,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            const Color(0xFFF97316), // orange-500
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandLogo(size: 56),
          const SizedBox(height: 12),
          const Text(
            '¡Bienvenido a Kronio!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onAction,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              side: const BorderSide(color: Colors.white),
            ),
            icon: const Icon(Icons.search),
            label: const Text('Explorar productos'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;

  const _SectionTitle({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
      ],
    );
  }
}

class _CategoriesStrip extends StatelessWidget {
  final List<Category> categories;

  const _CategoriesStrip({required this.categories});

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    final icons = {
      'Salud': Icons.health_and_safety,
      'Tecnología': Icons.devices,
      'Tecnologia': Icons.devices,
      'Belleza': Icons.spa,
      'Moda': Icons.checkroom,
      'Hogar': Icons.chair,
    };

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final c = categories[index];
          final icon = icons[c.name] ?? Icons.category;
          return Column(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                c.name,
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorBox({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, color: Colors.red, size: 40),
          const SizedBox(height: 8),
          const Text(
            'No pudimos cargar los productos',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  const _CartButton();

  @override
  Widget build(BuildContext context) {
    final cart = CartScope.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.shopping_cart_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CartScreen()),
          ),
        ),
        if (cart.totalItems > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: Text(
                  '${cart.totalItems}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}