import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/network_providers.dart';
import 'admin_ui.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Map<String, dynamic>? product;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController();
  final _imageUrl = TextEditingController();
  final _imageUrls = <String>[];
  final _sizes = <String>{};
  final _images = <(String, Uint8List)>[];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _subCategories = [];
  String? _category;
  String? _subCategory;
  bool _bestseller = false;
  bool _active = true;
  bool _busy = false;
  String? _error;

  bool get _editing => widget.product != null;
  Dio get _dio => ref.read(dioProvider);

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    if (product != null) {
      _name.text = '${product['name']}';
      _description.text = '${product['description']}';
      _price.text = '${product['price']}';
      _category = '${product['category']}';
      _subCategory = '${product['subCategory']}';
      _sizes.addAll((product['sizes'] as List).cast<String>());
      _bestseller = product['bestseller'] == true;
      _active = product['active'] != false;
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _stock.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  String _message(DioException e) {
    final body = e.response?.data;
    return body is Map && body['message'] != null
        ? '${body['message']}'
        : e.message ?? 'Request failed';
  }

  Future<void> _loadCategories() async {
    try {
      final data = (await _dio.get<List<dynamic>>(
        '/api/admin/categories',
      )).data!;
      if (!mounted) return;
      setState(
        () => _categories = data
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
      await _loadSubCategories();
    } on DioException catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  Future<void> _loadSubCategories() async {
    final category = _categories
        .where((e) => e['name'] == _category)
        .firstOrNull;
    if (category == null) {
      setState(() => _subCategories = []);
      return;
    }
    try {
      final data = (await _dio.get<List<dynamic>>(
        '/api/admin/categories/${category['id']}/sub-categories',
      )).data!;
      if (mounted) {
        setState(
          () => _subCategories = data
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        );
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  Future<void> _pickImages() async {
    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
      if (picked.isEmpty || !mounted) return;
      if (_images.length + _imageUrls.length + picked.length > 4) {
        setState(() => _error = 'A product can have at most 4 images.');
        return;
      }
      final additions = <(String, Uint8List)>[];
      for (final file in picked) {
        final bytes = await file.readAsBytes();
        if (bytes.length > 5 * 1024 * 1024) {
          if (mounted) setState(() => _error = '${file.name} exceeds 5 MB.');
          return;
        }
        final lower = file.name.toLowerCase();
        if (!['.png', '.jpg', '.jpeg', '.webp', '.gif'].any(lower.endsWith)) {
          if (mounted) {
            setState(() => _error = '${file.name} is not a supported image.');
          }
          return;
        }
        additions.add((file.name, bytes));
      }
      if (mounted) {
        setState(() {
          _images.addAll(additions);
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not select images: $e');
    }
  }

  /// "S 4 · M 8" from the product's `stock` map.
  String _currentStock() {
    final stock = widget.product?['stock'];
    if (stock is! Map || stock.isEmpty) return 'unknown';
    return stock.entries.map((e) => '${e.key} ${e.value}').join(' · ');
  }

  /// Adds the typed image URL (http/https only, at most 4 images in total).
  void _addImageUrl() {
    final error = validateImageUrl(
      _imageUrl.text,
      existing: _imageUrls,
      total: _images.length + _imageUrls.length,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _imageUrls.add(_imageUrl.text.trim());
      _imageUrl.clear();
      _error = null;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final imageCount = _images.length + _imageUrls.length;
    if (_category == null ||
        _subCategory == null ||
        _sizes.isEmpty ||
        (!_editing && imageCount == 0)) {
      setState(
        () => _error =
            'Choose a category, subcategory, size, and at least one image '
            '(photo or URL) for a new product.',
      );
      return;
    }
    if (imageCount > 4) {
      setState(() => _error = 'A product can have at most 4 images.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final form = FormData();
      form.fields.addAll([
        MapEntry('name', _name.text.trim()),
        MapEntry('description', _description.text.trim()),
        MapEntry('price', _price.text.trim()),
        MapEntry('category', _category!),
        MapEntry('subCategory', _subCategory!),
        MapEntry('bestseller', '$_bestseller'),
        MapEntry('active', '$_active'),
        // Blank on edit = keep each size's current stock.
        if (_stock.text.trim().isNotEmpty)
          MapEntry('stock', _stock.text.trim()),
        for (final size in _sizes) MapEntry('sizes', size),
        for (final url in _imageUrls) MapEntry('imageUrls', url),
      ]);
      for (final image in _images) {
        form.files.add(
          MapEntry(
            'images',
            MultipartFile.fromBytes(image.$2, filename: image.$1),
          ),
        );
      }
      if (_editing) {
        await _dio.put(
          '/api/admin/products/${widget.product!['id']}',
          data: form,
        );
      } else {
        await _dio.post('/api/admin/products', data: form);
      }
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingImages = (widget.product?['images'] as List? ?? [])
        .cast<String>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit product' : 'Add product'),
        backgroundColor: AppColors.surface,
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const AdminSectionHeading('Product details'),
            TextFormField(
              controller: _name,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Description is required'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Price'),
              validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                  ? 'Enter a price above zero'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('product-stock'),
              controller: _stock,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Stock quantity (per size)',
                helperText: _editing
                    ? 'Now: ${_currentStock()}. Leave blank to keep it; a '
                          'number sets every size to it.'
                    : 'Units of each size. Blank = 20 per size.',
                helperMaxLines: 2,
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return null;
                final n = int.tryParse(t);
                if (n == null || n < 0 || n > 100000) {
                  return 'Enter a whole number from 0 to 100000';
                }
                return null;
              },
            ),
            const AdminSectionHeading('Placement and sizing'),
            DropdownButtonFormField<String>(
              key: ValueKey('category-${_categories.length}-$_category'),
              initialValue: _categories.any((e) => e['name'] == _category)
                  ? _category
                  : null,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in _categories)
                  DropdownMenuItem(
                    value: '${c['name']}',
                    child: Text('${c['name']}'),
                  ),
              ],
              onChanged: (v) {
                setState(() {
                  _category = v;
                  _subCategory = null;
                });
                _loadSubCategories();
              },
              validator: (_) => _category == null ? 'Choose a category' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(
                'sub-$_category-${_subCategories.length}-$_subCategory',
              ),
              initialValue: _subCategories.any((e) => e['name'] == _subCategory)
                  ? _subCategory
                  : null,
              decoration: const InputDecoration(labelText: 'Subcategory'),
              items: [
                for (final c in _subCategories)
                  DropdownMenuItem(
                    value: '${c['name']}',
                    child: Text('${c['name']}'),
                  ),
              ],
              onChanged: (v) => setState(() => _subCategory = v),
              validator: (_) =>
                  _subCategory == null ? 'Choose a subcategory' : null,
            ),
            const SizedBox(height: 18),
            const Text(
              'Available sizes',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final size in ['S', 'M', 'L', 'XL', 'XXL'])
                  FilterChip(
                    label: Text(size),
                    selected: _sizes.contains(size),
                    onSelected: (selected) => setState(
                      () => selected ? _sizes.add(size) : _sizes.remove(size),
                    ),
                  ),
              ],
            ),
            AdminSurface(
              padding: EdgeInsets.zero,
              child: SwitchListTile(
                title: const Text(
                  'Best seller',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Feature this item in the shop'),
                value: _bestseller,
                onChanged: (v) => setState(() => _bestseller = v),
              ),
            ),
            AdminSurface(
              padding: EdgeInsets.zero,
              child: SwitchListTile(
                key: const Key('product-active'),
                title: const Text(
                  'Active',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _active
                      ? 'Visible in the shop'
                      : 'Hidden from shoppers (inactive)',
                ),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            ),
            const AdminSectionHeading('Product photos'),
            Text(
              _editing
                  ? 'Adding photos or URLs replaces all current photos (max 4).'
                  : 'Choose 1 to 4 photos (max 5 MB each) and/or image URLs.',
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            if (_editing && _images.isEmpty && existingImages.isNotEmpty)
              SizedBox(
                height: 90,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final url in existingImages)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Image.network(
                          url,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                  ],
                ),
              ),
            if (_images.isNotEmpty)
              SizedBox(
                height: 90,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (var i = 0; i < _images.length; i++)
                      Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Image.memory(
                              _images[i].$2,
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: 5,
                            top: 0,
                            child: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () =>
                                  setState(() => _images.removeAt(i)),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickImages,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_editing ? 'Replace images' : 'Choose images'),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('product-image-url'),
                    controller: _imageUrl,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Or add an image URL (https://…)',
                    ),
                    onSubmitted: (_) => _addImageUrl(),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    key: const Key('product-add-image-url'),
                    onPressed: _busy ? null : _addImageUrl,
                    child: const Text('Add'),
                  ),
                ),
              ],
            ),
            for (var i = 0; i < _imageUrls.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _imageUrls[i],
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 48,
                      height: 48,
                      color: AppColors.fill,
                      child: const Icon(Icons.link, size: 20),
                    ),
                  ),
                ),
                title: Text(
                  _imageUrls[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'Remove URL',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _imageUrls.removeAt(i)),
                ),
              ),
            if (_error != null)
              AdminSurface(
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check),
            label: Text(_busy ? 'Saving product…' : 'Save product'),
          ),
        ),
      ),
    );
  }
}

/// Null when [raw] is an acceptable product image URL, else the reason.
/// Mirrors the API's rule: http/https only, at most 4 images per product.
String? validateImageUrl(
  String raw, {
  List<String> existing = const [],
  int total = 0,
}) {
  final value = raw.trim();
  if (value.isEmpty) return 'Enter an image URL.';
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      uri.host.isEmpty) {
    return 'Image URLs must start with http:// or https://';
  }
  if (existing.contains(value)) return 'That image URL is already added.';
  if (total >= 4) return 'A product can have at most 4 images.';
  return null;
}
