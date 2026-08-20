/// pocketbase-specific function to strip the id from the file name
String stripIDFromFileName(String fileName) {
  final RegExp identifierPattern = RegExp(r'_[a-zA-Z0-9]+(?=\.[^.]+$)');
  return fileName.replaceAll(identifierPattern, '');
}
