import 'package:flutter/material.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Padding(
        padding: const EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 16.0,
          bottom: 100.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF8B95A5)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        child: const Icon(
                          Icons.clear,
                          color: Color(0xFF8B95A5),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE8ECEF)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE8ECEF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF2D8E7F),
                    width: 2,
                  ),
                ),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
            const SizedBox(height: 32),
            if (_searchController.text.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Searches',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF1C2A3A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSearchItem('Flutter Tips'),
                  const SizedBox(height: 12),
                  _buildSearchItem('Mobile Apps'),
                  const SizedBox(height: 12),
                  _buildSearchItem('Design Patterns'),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Results for "${_searchController.text}"',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF1C2A3A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildResultItem('Result 1'),
                  const SizedBox(height: 12),
                  _buildResultItem('Result 2'),
                  const SizedBox(height: 12),
                  _buildResultItem('Result 3'),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchItem(String text) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8ECEF)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.history, color: Color(0xFF8B95A5), size: 18),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(fontSize: 14, color: Color(0xFF1C2A3A)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(String text) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8ECEF)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.file_present, color: Color(0xFF2D8E7F), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1C2A3A)),
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF8B95A5)),
        ],
      ),
    );
  }
}
