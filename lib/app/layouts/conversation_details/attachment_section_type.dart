/// Attachment categories shown in conversation details and the attachments page.
enum AttachmentSectionType {
  media,
  links,
  locations,
  documents,
}

/// Max items shown per section on the conversation details preview.
const int kAttachmentPreviewLimit = 6;

extension AttachmentSectionTypeLabels on AttachmentSectionType {
  String get title {
    switch (this) {
      case AttachmentSectionType.media:
        return "IMAGES & VIDEOS";
      case AttachmentSectionType.links:
        return "LINKS";
      case AttachmentSectionType.locations:
        return "LOCATIONS";
      case AttachmentSectionType.documents:
        return "OTHER FILES";
    }
  }
}
