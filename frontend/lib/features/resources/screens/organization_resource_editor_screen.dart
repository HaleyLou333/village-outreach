import 'package:flutter/material.dart';
import '../services/organization_resource_service.dart';

/// The API is the source of truth for membership and resource ownership.
class OrganizationResourceEditorScreen extends StatefulWidget {
  final OrganizationResourceRepository? repository;
  const OrganizationResourceEditorScreen({super.key, this.repository});
  @override
  State<OrganizationResourceEditorScreen> createState() => _OrganizationResourceEditorScreenState();
}

class _OrganizationResourceEditorScreenState extends State<OrganizationResourceEditorScreen> {
  late final OrganizationResourceRepository _repo;
  List<OrganizationMembership> _organizations = [];
  List<ManagedResource> _resources = [];
  String? _selectedId;
  String? _error;
  bool _loading = true;
  @override
  void initState() { super.initState(); _repo = widget.repository ?? OrganizationResourceService(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final memberships = (await _repo.memberships()).where((m) => m.canManage).toList();
      final selected = memberships.any((m) => m.organizationId == _selectedId)
          ? _selectedId : (memberships.isEmpty ? null : memberships.first.organizationId);
      final resources = selected == null ? <ManagedResource>[] : await _repo.resources(selected);
      if (!mounted) { return; }
      setState(() { _organizations = memberships; _selectedId = selected; _resources = resources; _loading = false; });
    } catch (_) {
      if (!mounted) { return; }
      setState(() { _loading = false; _organizations = []; _resources = []; _selectedId = null;
        _error = 'Unable to verify organization access. Please retry.'; });
    }
  }
  Future<void> _select(String id) async { setState(() => _selectedId = id); await _load(); }
  Future<void> _edit([ManagedResource? resource]) async {
    final org = _selectedId;
    if (org == null || !_organizations.any((m) => m.organizationId == org && m.canManage)) { return; }
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => OrganizationResourceForm(repository: _repo, organizationId: org, resource: resource)));
    if (saved == true && mounted) { await _load(); }
  }
  Future<void> _disable(ManagedResource resource) async {
    if (resource.organizationId != _selectedId) { return; }
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Disable resource?'), content: Text('Hide ${resource.name} from public resource browsing?'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Disable'))]));
    if (confirm != true || !mounted) { return; }
    try { await _repo.disable(resource.id); await _load(); }
    catch (_) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not disable resource. Please retry.'))); } }
  }
  @override
  void dispose() { if (widget.repository == null) { (_repo as OrganizationResourceService).dispose(); } super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Manage organization resources')),
    body: _loading ? const Center(child: CircularProgressIndicator())
      : _error != null ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!), TextButton(onPressed: _load, child: const Text('Retry'))]))
      : _organizations.isEmpty ? const Center(child: Text('No approved organization memberships.'))
      : ListView(padding: const EdgeInsets.all(16), children: [
          DropdownButtonFormField<String>(initialValue: _selectedId,
            decoration: const InputDecoration(labelText: 'Organization'),
            items: _organizations.map((m) => DropdownMenuItem(value: m.organizationId, child: Text(m.name))).toList(),
            onChanged: (id) { if (id != null) _select(id); }),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Add resource')),
          for (final resource in _resources) Card(child: ListTile(
            title: Text(resource.name), subtitle: Text(resource.isActive ? 'Active' : 'Disabled'),
            trailing: Wrap(children: [
              IconButton(tooltip: 'Edit resource', icon: const Icon(Icons.edit), onPressed: () => _edit(resource)),
              if (resource.isActive) IconButton(tooltip: 'Disable resource', icon: const Icon(Icons.block),
                onPressed: () => _disable(resource)),
            ]))),
        ]),
  );
}

class OrganizationResourceForm extends StatefulWidget {
  final OrganizationResourceRepository repository;
  final String organizationId;
  final ManagedResource? resource;
  const OrganizationResourceForm({super.key, required this.repository,
    required this.organizationId, this.resource});
  @override
  State<OrganizationResourceForm> createState() => _OrganizationResourceFormState();
}

class _OrganizationResourceFormState extends State<OrganizationResourceForm> {
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _fields = {};
  bool _saving = false;
  String? _error;
  static const _keys = ['name', 'category', 'area', 'address', 'latitude', 'longitude', 'phone', 'website', 'source_url'];
  @override
  void initState() {
    super.initState();
    for (final key in _keys) { _fields[key] = TextEditingController(text: widget.resource?.fields[key]?.toString() ?? ''); }
  }
  @override
  void dispose() { for (final c in _fields.values) { c.dispose(); } super.dispose(); }
  String? _validate(String key, String? value) {
    final text = (value ?? '').trim();
    if (!['phone', 'website'].contains(key) && text.isEmpty) { return 'Required field'; }
    if (key == 'name' && text.length > 160) { return 'Maximum 160 characters'; }
    if (key == 'area' && text.length > 100) { return 'Maximum 100 characters'; }
    if (key == 'address' && text.length > 300) { return 'Maximum 300 characters'; }
    if (key == 'category' && !RegExp(r'^[a-z][a-z0-9_]{0,39}$').hasMatch(text)) { return 'Use lowercase letters, digits, underscores'; }
    if (key == 'phone' && text.length > 40) { return 'Maximum 40 characters'; }
    if (key == 'phone' && text.isNotEmpty && !RegExp(r'^[+0-9() .-]{7,40}$').hasMatch(text)) { return 'Enter a valid phone number'; }
    if ((key == 'website' || key == 'source_url') && text.isNotEmpty &&
        (text.length > 2048 || !(Uri.tryParse(text)?.hasAuthority ?? false) ||
         !['http', 'https'].contains(Uri.tryParse(text)?.scheme))) {
      return 'Enter a valid http(s) URL';
    }
    if (key == 'latitude' || key == 'longitude') {
      final n = double.tryParse(text);
      final limit = key == 'latitude' ? 90 : 180;
      if (n == null || !n.isFinite || n < -limit || n > limit) { return 'Enter a coordinate between -$limit and $limit'; }
    }
    return null;
  }
  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) { return; }
    setState(() { _saving = true; _error = null; });
    final data = <String, dynamic>{};
    for (final key in _keys) {
      final value = _fields[key]!.text.trim();
      data[key] = key == 'latitude' || key == 'longitude' ? double.parse(value)
        : (['phone', 'website'].contains(key) && value.isEmpty ? null : value);
    }
    try {
      if (widget.resource == null) { await widget.repository.create(widget.organizationId, data); }
      else { await widget.repository.update(widget.resource!.id, data); }
      if (mounted) { Navigator.of(context).pop(true); }
    } catch (_) {
      if (mounted) { setState(() { _error = 'Could not save. Check your permissions and fields, then retry.'; _saving = false; }); }
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.resource == null ? 'Add resource' : 'Edit resource')),
    body: Form(key: _form, child: ListView(padding: const EdgeInsets.all(16), children: [
      for (final key in _keys) Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(
        controller: _fields[key], decoration: InputDecoration(labelText: key.replaceAll('_', ' ')),
        keyboardType: ['latitude', 'longitude'].contains(key) ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : key == 'phone' ? TextInputType.phone : TextInputType.text,
        validator: (value) => _validate(key, value),
      )),
      if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      FilledButton(onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving...' : 'Save resource')),
    ])),
  );
}
