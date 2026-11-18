/// Conversion direction of the app.
enum ConvertMode {
  /// Word document in, Markdown out.
  docx2md,

  /// Markdown in, Word document out.
  md2docx;

  /// The opposite direction.
  ConvertMode get other =>
      this == ConvertMode.docx2md ? ConvertMode.md2docx : ConvertMode.docx2md;

  /// Label shown in the header for the input side.
  String get fromLabel => this == ConvertMode.docx2md ? 'DOCX' : 'Markdown';

  /// Label shown in the header for the output side.
  String get toLabel => this == ConvertMode.docx2md ? 'Markdown' : 'DOCX';
}
