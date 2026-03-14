String abbreviatePath(String path) {
  const home = '/home/';
  if (path.startsWith(home)) {
    final rest = path.substring(home.length);
    final parts = rest.split('/');
    if (parts.length > 1) {
      return '~/${parts.sublist(1).join('/')}';
    }
    return '~';
  }
  return path;
}
