import 'package:flutter/material.dart';
import 'package:is_it_enough/core/constants/monitor_list_modes.dart';
import 'package:is_it_enough/features/settings/data/installed_apps_service.dart';

/// 名单应用选择页。
///
/// 列出本机带桌面图标的应用（读取清单不联网、不上传），支持搜索与全选，
/// 保存后把选中的包名集合回传给设置页。
class AppPickerPage extends StatefulWidget {
  const AppPickerPage({
    super.key,
    required this.mode,
    required this.initialSelected,
  });

  final MonitorListMode mode;
  final Set<String> initialSelected;

  @override
  State<AppPickerPage> createState() => _AppPickerPageState();
}

class _AppPickerPageState extends State<AppPickerPage> {
  final TextEditingController _searchController = TextEditingController();
  late Set<String> _selected;
  List<InstalledApp> _apps = const <InstalledApp>[];
  bool _loading = true;
  bool _showSystemApps = false;
  String _keyword = '';

  bool get _isWhitelist => widget.mode == MonitorListMode.whitelist;

  @override
  void initState() {
    super.initState();
    _selected = <String>{...widget.initialSelected};
    _loadApps();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    final apps = await InstalledAppsService.listApps();
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _loading = false;
    });
  }

  List<InstalledApp> get _visibleApps {
    final keyword = _keyword.trim().toLowerCase();
    return _apps.where((app) {
      if (!_showSystemApps && app.isSystem) return false;
      if (keyword.isEmpty) return true;
      return app.label.toLowerCase().contains(keyword) ||
          app.packageName.toLowerCase().contains(keyword);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleApps;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isWhitelist ? '选择要监控的应用' : '选择不监控的应用'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _selected = <String>{}),
            child: const Text('清空'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _keyword = value),
                  decoration: InputDecoration(
                    hintText: '搜索应用名或包名',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _keyword.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _keyword = '');
                            },
                          ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _showSystemApps,
                  onChanged: (value) => setState(() => _showSystemApps = value),
                  title: const Text('显示系统应用', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('没有匹配的应用。'),
                        ),
                      )
                    : ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final app = visible[index];
                          final checked = _selected.contains(app.packageName);
                          return CheckboxListTile(
                            dense: true,
                            value: checked,
                            onChanged: (value) {
                              setState(() {
                                final next = <String>{..._selected};
                                if (value == true) {
                                  next.add(app.packageName);
                                } else {
                                  next.remove(app.packageName);
                                }
                                _selected = next;
                              });
                            },
                            title: Text(
                              app.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              app.packageName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '已选 ${_selected.length} 个应用',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_selected),
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
