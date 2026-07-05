enum NotePageKind { note, list, tracker, database, folder }

enum NoteBlockType {
  paragraph,
  heading1,
  heading2,
  bulletList,
  numberedList,
  checklist,
  quote,
  callout,
  image,
  divider,
}

enum NoteBlockStyle { normal, heading1, heading2, quote, callout }

enum NoteTextAlignment { left, center, right, justify }

enum NoteListMarkerStyle { automatic, numbered, lettered }

class NoteBlock {
  const NoteBlock({
    required this.id,
    required this.type,
    this.text = '',
    this.isChecked = false,
    this.imagePath,
    this.style = NoteBlockStyle.normal,
    this.colorValue,
    this.fontFamily = 'Inter',
    this.fontSize,
    this.textColorValue,
    this.textAlignment = NoteTextAlignment.left,
    this.listMarkerStyle = NoteListMarkerStyle.automatic,
    this.checklistStates = const <bool>[],
    this.groupId,
    this.groupTitle = '',
    this.groupCollapsed = false,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
  });

  final String id;
  final NoteBlockType type;
  final String text;
  final bool isChecked;
  final String? imagePath;
  final NoteBlockStyle style;
  final int? colorValue;
  final String fontFamily;
  final double? fontSize;
  final int? textColorValue;
  final NoteTextAlignment textAlignment;
  final NoteListMarkerStyle listMarkerStyle;
  final List<bool> checklistStates;
  final String? groupId;
  final String groupTitle;
  final bool groupCollapsed;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;

  NoteBlock copyWith({
    NoteBlockType? type,
    String? text,
    bool? isChecked,
    String? imagePath,
    bool clearImagePath = false,
    NoteBlockStyle? style,
    int? colorValue,
    bool clearColorValue = false,
    String? fontFamily,
    double? fontSize,
    bool clearFontSize = false,
    int? textColorValue,
    bool clearTextColorValue = false,
    NoteTextAlignment? textAlignment,
    NoteListMarkerStyle? listMarkerStyle,
    List<bool>? checklistStates,
    bool clearChecklistStates = false,
    String? groupId,
    bool clearGroupId = false,
    String? groupTitle,
    bool? groupCollapsed,
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
  }) {
    return NoteBlock(
      id: id,
      type: type ?? this.type,
      text: text ?? this.text,
      isChecked: isChecked ?? this.isChecked,
      imagePath: clearImagePath ? null : imagePath ?? this.imagePath,
      style: style ?? this.style,
      colorValue: clearColorValue ? null : colorValue ?? this.colorValue,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: clearFontSize ? null : fontSize ?? this.fontSize,
      textColorValue: clearTextColorValue
          ? null
          : textColorValue ?? this.textColorValue,
      textAlignment: textAlignment ?? this.textAlignment,
      listMarkerStyle: listMarkerStyle ?? this.listMarkerStyle,
      checklistStates: clearChecklistStates
          ? const <bool>[]
          : checklistStates ?? this.checklistStates,
      groupId: clearGroupId ? null : groupId ?? this.groupId,
      groupTitle: groupTitle ?? this.groupTitle,
      groupCollapsed: groupCollapsed ?? this.groupCollapsed,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
    );
  }
}

class NoteMindMapPosition {
  const NoteMindMapPosition({
    required this.pageId,
    required this.scopeId,
    required this.x,
    required this.y,
  });

  final String pageId;
  final String scopeId;
  final double x;
  final double y;
}

class NotePage {
  const NotePage({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.blocks,
    this.kind = NotePageKind.note,
    this.isPinned = false,
    this.boardX,
    this.boardY,
    this.parentFolderId,
    this.folderOrder = 0,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<NoteBlock> blocks;
  final NotePageKind kind;
  final bool isPinned;

  // Posición persistente dentro del Modo Pizarrón.
  final double? boardX;
  final double? boardY;

  // Carpeta que contiene este elemento.
  // null significa que está en la raíz de Notas.
  final String? parentFolderId;

  // Posición relativa dentro de la carpeta.
  final int folderOrder;

  bool get hasBoardPosition {
    return boardX != null && boardY != null;
  }

  bool get isFolder {
    return kind == NotePageKind.folder;
  }

  bool get isRootItem {
    return parentFolderId == null;
  }

  NotePage copyWith({
    String? title,
    DateTime? updatedAt,
    List<NoteBlock>? blocks,
    NotePageKind? kind,
    bool? isPinned,
    double? boardX,
    double? boardY,
    bool clearBoardPosition = false,
    String? parentFolderId,
    bool clearParentFolderId = false,
    int? folderOrder,
  }) {
    return NotePage(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      blocks: blocks ?? this.blocks,
      kind: kind ?? this.kind,
      isPinned: isPinned ?? this.isPinned,
      boardX: clearBoardPosition ? null : boardX ?? this.boardX,
      boardY: clearBoardPosition ? null : boardY ?? this.boardY,
      parentFolderId: clearParentFolderId
          ? null
          : parentFolderId ?? this.parentFolderId,
      folderOrder: folderOrder ?? this.folderOrder,
    );
  }
}
