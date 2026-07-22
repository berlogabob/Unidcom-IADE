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
  String? _type;
  String? _quartile;
  String? _approvalStatus;
  late Future<List<Map<String, dynamic>>> _outputs = fetchOutputs();
  late final Future<List<String>> _types = fetchDistinctOutputTypes();

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _load() {
    final year = int.tryParse(_year);
    setState(
      () => _outputs = fetchOutputs(
        query: _query,
        year: year,
        type: _type,
        quartile: _quartile,
        approvalStatus: _approvalStatus,
      ),
    );
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
          FutureBuilder<List<String>>(
            future: _types,
            builder: (context, snapshot) {
              return _filters(snapshot.data ?? []);
            },
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

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${outputs.length} outputs',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: outputs.isEmpty
                          ? const Center(child: Text('No outputs found'))
                          : ListView.builder(
                              itemCount: outputs.length,
                              itemBuilder: (context, index) {
                                final output = outputs[index];
                                final authors =
                                    (output['output_authors']
                                                as List<dynamic>? ??
                                            [])
                                        .map((author) {
                                          final people =
                                              (author
                                                  as Map<
                                                    String,
                                                    dynamic
                                                  >)['people'];
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
                                  title:
                                      output['title'] as String? ?? 'Untitled',
                                  year: output['reporting_year'] as int?,
                                  type: output['type'] as String?,
                                  detail: authors,
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters(List<String> types) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _dropdown('Type', _type, types, (value) {
          _type = value;
          _load();
        }, width: 240),
        _dropdown('Quartile', _quartile, const ['Q1', 'Q2', 'Q3', 'Q4'], (
          value,
        ) {
          _quartile = value;
          _load();
        }),
        _dropdown(
          'Approval',
          _approvalStatus,
          const ['pending', 'approved', 'rejected'],
          (value) {
            _approvalStatus = value;
            _load();
          },
        ),
      ],
    );
  }

  Widget _dropdown(
    String label,
    String? value,
    List<String> values,
    ValueChanged<String?> onChanged, {
    double width = 160,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String?>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('All')),
          for (final item in values)
            DropdownMenuItem(value: item, child: Text(item)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
