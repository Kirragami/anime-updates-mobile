import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../constants/app_constants.dart';
import '../models/tomodachi.dart';
import '../providers/auth_provider.dart';
import '../providers/friends_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/error_widget.dart' as error_widgets;

class TomodachiScreen extends ConsumerStatefulWidget {
  const TomodachiScreen({super.key});

  @override
  ConsumerState<TomodachiScreen> createState() => _TomodachiScreenState();
}

class _TomodachiScreenState extends ConsumerState<TomodachiScreen> {
  late RefreshController _refreshController;
  final TextEditingController _usernameController = TextEditingController();
  final FocusNode _usernameFocusNode = FocusNode();
  bool _showAddInput = false;
  bool _isSubmitting = false;
  String? _processingUsername;

  @override
  void initState() {
    super.initState();
    _refreshController = RefreshController(initialRefresh: false);
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _usernameController.dispose();
    _usernameFocusNode.dispose();
    super.dispose();
  }

  void _toggleAddInput() {
    setState(() {
      _showAddInput = !_showAddInput;
      if (_showAddInput) {
        _usernameFocusNode.requestFocus();
      } else {
        _usernameController.clear();
        _usernameFocusNode.unfocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authProvider);
    final tomodachiAsync = ref.watch(tomodachiNotifierProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              userAsync.when(
                data: (user) => _buildHeader(user?.username),
                loading: () => _buildHeader(null),
                error: (_, __) => _buildHeader(null),
              ),
              Expanded(
                child: tomodachiAsync.when(
                  data: (list) => _buildContent(list),
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  error: (error, _) => error_widgets.CustomErrorWidget(
                    message: error.toString().replaceFirst('Exception: ', ''),
                    onRetry: () =>
                        ref.read(tomodachiNotifierProvider.notifier).refresh(),
                    showRetryButton: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String? username) {
    final displayName = username != null && username.isNotEmpty
        ? '${username[0].toUpperCase()}${username.substring(1)}-sama'
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (_showAddInput) {
                    _toggleAddInput();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                child: const SizedBox(
                  width: 14,
                  height: 32,
                  child: Center(
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
              if (!_showAddInput) ...[
                const SizedBox(width: 16),
                const Text(
                  'Tomodachi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  tooltip: 'Add tomodachi',
                  icon: const Icon(
                    Icons.person_add_outlined,
                    color: AppTheme.textPrimary,
                    size: 22,
                  ),
                  onPressed: _toggleAddInput,
                ),
              ] else ...[
                const SizedBox(width: 12),
                Expanded(child: _buildAddInput()),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddInput() {
    return AnimatedContainer(
      duration: AppConstants.mediumAnimation,
      curve: Curves.easeOutCubic,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.18),
            blurRadius: 16,
            spreadRadius: 0.5,
            offset: Offset.zero,
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(
            Icons.person_outline,
            color: AppTheme.primaryColor,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _usernameController,
              focusNode: _usernameFocusNode,
              enabled: !_isSubmitting,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Username',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitAddRequest(),
            ),
          ),
          if (_isSubmitting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryColor,
                ),
              ),
            )
          else
            GestureDetector(
              onTap: _submitAddRequest,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.send_rounded,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(List<Tomodachi> list) {
    final incomingRequests =
        list.where((t) => t.isPending && !t.isSender).toList();
    final outgoingRequests =
        list.where((t) => t.isPending && t.isSender).toList();
    final acceptedFriends = list.where((t) => t.isAccepted).toList();

    return SmartRefresher(
      controller: _refreshController,
      enablePullDown: true,
      enablePullUp: false,
      header: const WaterDropHeader(
        waterDropColor: AppTheme.primaryColor,
      ),
      onRefresh: () async {
        await ref.read(tomodachiNotifierProvider.notifier).refresh();
        _refreshController.refreshToIdle();
      },
      child: list.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              children: [
                Text(
                  'No tomodachi yet',
                  style: AppTheme.heading3.copyWith(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap + and enter an exact username to connect.',
                  style: AppTheme.body2,
                  textAlign: TextAlign.center,
                ),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (incomingRequests.isNotEmpty) ...[
                  _buildSection('Requests', incomingRequests.map(
                    (t) => _buildRequestRow(t, isIncoming: true),
                  )),
                  const SizedBox(height: 20),
                ],
                if (outgoingRequests.isNotEmpty) ...[
                  _buildSection('Sent', outgoingRequests.map(
                    (t) => _buildRequestRow(t, isIncoming: false),
                  )),
                  const SizedBox(height: 20),
                ],
                _buildSection(
                  'My Tomodachi',
                  acceptedFriends.isEmpty
                      ? [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Text(
                              'No tomodachi yet.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ]
                      : acceptedFriends.map(_buildFriendRow),
                ),
              ],
            ),
    );
  }

  Widget _buildSection(String title, Iterable<Widget> children) {
    final items = children.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildRequestRow(Tomodachi tomodachi, {required bool isIncoming}) {
    final isProcessing = _processingUsername == tomodachi.username;

    return _buildListRow(
      username: tomodachi.username,
      subtitle: isIncoming ? 'Incoming request' : 'Pending',
      actions: isProcessing
          ? [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryColor,
                ),
              ),
            ]
          : isIncoming
              ? [
                  _textAction(
                    'Accept',
                    onTap: () => _acceptRequest(tomodachi.username),
                  ),
                  _textAction(
                    'Decline',
                    onTap: () => _declineRequest(tomodachi.username),
                    muted: true,
                  ),
                ]
              : [
                  _textAction(
                    'Cancel',
                    onTap: () => _removeFriend(tomodachi.username),
                    muted: true,
                  ),
                ],
    );
  }

  Widget _buildFriendRow(Tomodachi tomodachi) {
    return _buildListRow(
      username: tomodachi.username,
      actions: [
        _textAction(
          'Untomodachi',
          onTap: () => _confirmUnfriend(tomodachi.username),
          muted: true,
        ),
      ],
    );
  }

  Widget _buildListRow({
    required String username,
    String? subtitle,
    required List<Widget> actions,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Row(
        children: [
          _buildAvatar(username),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }

  Widget _buildAvatar(String username) {
    final initial =
        username.isNotEmpty ? username[0].toUpperCase() : '?';
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _textAction(
    String label, {
    required VoidCallback onTap,
    bool muted = false,
  }) {
    return TextButton(
      onPressed: _processingUsername != null ? null : onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: muted ? Colors.white.withOpacity(0.6) : AppTheme.primaryColor,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _runAction(
    String username,
    Future<Map<String, dynamic>> Function() action,
  ) async {
    if (_processingUsername != null) {
      return;
    }

    setState(() => _processingUsername = username);
    final result = await action();
    if (!mounted) {
      return;
    }
    setState(() => _processingUsername = null);
    _showSnack(
      result['success'] == true
          ? (result['message'] as String? ?? 'Success')
          : (result['message'] as String? ?? 'Request failed'),
    );
  }

  Future<void> _submitAddRequest() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      _showSnack('Enter a username');
      return;
    }

    setState(() => _isSubmitting = true);
    final result =
        await ref.read(tomodachiNotifierProvider.notifier).sendRequest(username);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      _usernameController.clear();
      setState(() => _showAddInput = false);
      _usernameFocusNode.unfocus();
      _showSnack(result['message'] as String? ?? 'Request sent');
    } else {
      _showSnack(result['message'] as String? ?? 'Failed to send request');
    }
  }

  Future<void> _acceptRequest(String username) async {
    await _runAction(
      username,
      () => ref.read(tomodachiNotifierProvider.notifier).acceptRequest(username),
    );
  }

  Future<void> _declineRequest(String username) async {
    await _runAction(
      username,
      () => ref.read(tomodachiNotifierProvider.notifier).declineRequest(username),
    );
  }

  Future<void> _confirmUnfriend(String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text(
          'Remove tomodachi?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Remove $username from your tomodachi list?',
          style: AppTheme.body2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Remove',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _removeFriend(username);
    }
  }

  Future<void> _removeFriend(String username) async {
    await _runAction(
      username,
      () => ref.read(tomodachiNotifierProvider.notifier).removeFriend(username),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.surfaceColor,
      ),
    );
  }
}
