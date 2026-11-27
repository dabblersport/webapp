/// Which sport chips Manage Sports shows ticked (KAN-1057).
///
/// The ticked set is the profile's interests plus whatever [mySportsProvider]
/// reports. A removal unticks at once; ids removed in this sheet are never
/// re-ticked by a provider value that predates the refetch; a failed removal
/// is restored. Ids with a write in flight ignore further taps.
class SportSelection {
  SportSelection(Iterable<String> initial) : _ticked = {...initial};

  final Set<String> _ticked;
  final Set<String> _removed = {};
  final Set<String> _pending = {};

  bool isTicked(String id) => _ticked.contains(id);
  bool isPending(String id) => _pending.contains(id);
  int get count => _ticked.length;

  /// Merges ids from the provider, except those removed in this sheet.
  void mergeFromProvider(Iterable<String> ids) {
    _ticked.addAll(ids.where((id) => !_removed.contains(id)));
  }

  /// Starts a removal: unticks now. False when a write is already in flight.
  bool startRemove(String id) {
    if (!_pending.add(id)) return false;
    _ticked.remove(id);
    _removed.add(id);
    return true;
  }

  /// Starts an add. False when a write is already in flight.
  bool startAdd(String id) => _pending.add(id);

  /// Ends the write on [id]. A failed remove re-ticks it; a successful add
  /// ticks it.
  void finish(String id, {required bool removing, required bool ok}) {
    _pending.remove(id);
    if (removing && !ok) {
      _removed.remove(id);
      _ticked.add(id);
    } else if (!removing && ok) {
      _removed.remove(id);
      _ticked.add(id);
    }
  }
}
