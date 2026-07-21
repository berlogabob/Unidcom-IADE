import 'dart:async';

import 'package:flutter/material.dart';

import '../data/supabase.dart';
import '../widgets/output_row.dart';
import '../widgets/search_bar.dart';

class OutputsScreen extends StatefulWidget {
  const OutputsScreen({super.key});

  @override
  State<OutputsScreen> createState() => _OutputsScreenState();
}

class _OutputsScreenState extends State<OutputsScreen> {
  Timer? _debounce;
  String _query = '';
  String _year = '';
  late Future<List<Map<String, dynamic>>> _outputs = fetchOutputs();

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _load() {
    final year = int.tryParse(_year);
    setState(() => _outputs = fetchOutputs(query: _query, year: year));
  }

  void _search(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: SearchBarField(onChanged: _search)),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: SearchBarField(
                  label: 'Year',
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    _year = value;
                    _load();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _outputs,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString()));
                }
                final outputs = snapshot.data ?? [];
                if (outputs.isEmpty) {
                  return const Center(child: Text('No outputs found'));
                }

                return ListView.builder(
                  itemCount: outputs.length,
                  itemBuilder: (context, index) {
                    final output = outputs[index];
                    final authors =
                        (output['output_authors'] as List<dynamic>? ?? [])
                            .map((author) {
                              final people =
                                  (author as Map<String, dynamic>)['people'];
                              return (people
                                      as Map<
                                        String,
                                        dynamic
                                      >?)?['preferred_name']
                                  as String?;
                            })
                            .whereType<String>()
                            .join(', ');
                    return OutputRow(
                      title: output['title'] as String? ?? 'Untitled',
                      year: output['reporting_year'] as int?,
                      type: output['type'] as String?,
                      detail: authors,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
