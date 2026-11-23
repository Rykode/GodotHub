String? _pendingAction;

void setPendingAction(String action) => _pendingAction = action;

bool consumePendingActionIf(String action) {
  if (_pendingAction != action) return false;
  _pendingAction = null;
  return true;
}

String? consumePendingAction() {
  final action = _pendingAction;
  _pendingAction = null;
  return action;
}
