import 'package:flutter/material.dart';

import '../models/team.dart';
import '../services/team_service.dart';

/// Searchable team picker with inline "+ Add" creation for a new team name.
class TeamDropdown extends StatefulWidget {
  final String label;
  final Team? initialTeam;
  final ValueChanged<Team> onSelected;

  const TeamDropdown({
    super.key,
    required this.label,
    required this.onSelected,
    this.initialTeam,
  });

  @override
  State<TeamDropdown> createState() => _TeamDropdownState();
}

class _TeamDropdownState extends State<TeamDropdown> {
  final TeamService _teamService = TeamService();
  bool _adding = false;
  String _queryText = '';

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Team>(
      initialValue: TextEditingValue(text: widget.initialTeam?.name ?? ''),
      displayStringForOption: (team) => team.name,
      optionsBuilder: (textEditingValue) async {
        _queryText = textEditingValue.text.trim();
        return _teamService.searchTeams(textEditingValue.text);
      },
      onSelected: widget.onSelected,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
            suffixIcon: _adding ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ) : null,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final query = _queryText;
        final exactMatch = options.any((o) => o.name.toLowerCase() == query.toLowerCase());
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260, maxWidth: 360),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final team in options)
                    ListTile(
                      title: Text(team.name),
                      onTap: () => onSelected(team),
                    ),
                  if (query.isNotEmpty && !exactMatch)
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: Text("Add '$query'"),
                      onTap: () async {
                        setState(() => _adding = true);
                        try {
                          final team = await _teamService.addTeam(query);
                          if (!mounted) return;
                          onSelected(team);
                        } finally {
                          if (mounted) setState(() => _adding = false);
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

}
