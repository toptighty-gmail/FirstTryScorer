import 'package:flutter/material.dart';

import '../models/team.dart';
import '../services/team_service.dart';

/// Searchable team picker with inline "+ Add" creation for a new team name.
class TeamDropdown extends StatefulWidget {
  final String label;
  final Team? initialTeam;
  final ValueChanged<Team> onSelected;
  final VoidCallback? onQueryChanged;

  const TeamDropdown({
    super.key,
    required this.label,
    required this.onSelected,
    this.initialTeam,
    this.onQueryChanged,
  });

  @override
  State<TeamDropdown> createState() => _TeamDropdownState();
}

class _TeamDropdownState extends State<TeamDropdown> {
  final TeamService _teamService = TeamService();
  bool _adding = false;
  String _queryText = '';

  Future<Team?> _saveTeam(String name, BuildContext context) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return null;

    setState(() => _adding = true);
    try {
      return await _teamService.addTeam(trimmedName);
    } catch (error) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not add team: $error')));
      return null;
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _showAddTeamDialog(
    BuildContext context,
    TextEditingController fieldController,
    FocusNode focusNode,
  ) async {
    final nameController = TextEditingController(text: _queryText);
    final teamName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add a team'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Team name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(nameController.text),
            child: const Text('Add team'),
          ),
        ],
      ),
    );
    final trimmedName = teamName?.trim();
    if (trimmedName == null ||
        trimmedName.isEmpty ||
        !mounted ||
        !context.mounted) {
      nameController.dispose();
      return;
    }

    final team = await _saveTeam(trimmedName, context);
    nameController.dispose();
    if (!mounted || team == null) return;

    fieldController.text = team.name;
    focusNode.unfocus();
    widget.onSelected(team);
  }

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
          onChanged: (_) => widget.onQueryChanged?.call(),
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_adding)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                IconButton(
                  tooltip: 'Add new team',
                  onPressed: _adding
                      ? null
                      : () =>
                            _showAddTeamDialog(context, controller, focusNode),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final query = _queryText;
        final exactMatch = options.any(
          (o) => o.name.toLowerCase() == query.toLowerCase(),
        );
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
                      enabled: !_adding,
                      onTap: () async {
                        final team = await _saveTeam(query, context);
                        if (mounted && team != null) onSelected(team);
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
