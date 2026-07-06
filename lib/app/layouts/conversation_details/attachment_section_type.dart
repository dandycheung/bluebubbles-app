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
  /// ALL CAPS label for section headers on the conversation details screen.
  String get sectionLabel {
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

  /// Title case label for the attachments page app bar.
  String get pageTitle {
    switch (this) {
      case AttachmentSectionType.media:
        return "Images & Videos";
      case AttachmentSectionType.links:
        return "Links";
      case AttachmentSectionType.locations:
        return "Locations";
      case AttachmentSectionType.documents:
        return "Other Files";
    }
  }
}
