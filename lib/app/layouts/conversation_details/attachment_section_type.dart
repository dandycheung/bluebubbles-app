import 'package:bluebubbles/database/models.dart';

/// Attachment categories shown in conversation details and the attachments page.
enum AttachmentSectionType {
  media,
  links,
  locations,
  documents,
}

/// Max items shown per section on the conversation details preview.
const int kAttachmentPreviewLimit = 6;

enum MediaFilter {
  all,
  images,
  videos,
}

extension MediaFilterLabels on MediaFilter {
  String get label {
    switch (this) {
      case MediaFilter.all:
        return "All";
      case MediaFilter.images:
        return "Images";
      case MediaFilter.videos:
        return "Videos";
    }
  }

  String get emptyMessage {
    switch (this) {
      case MediaFilter.all:
        return "No images or videos";
      case MediaFilter.images:
        return "No images";
      case MediaFilter.videos:
        return "No videos";
    }
  }
}

List<Attachment> filterMedia(List<Attachment> media, MediaFilter filter) {
  switch (filter) {
    case MediaFilter.all:
      return media;
    case MediaFilter.images:
      return media.where((e) => e.mimeStart == "image").toList();
    case MediaFilter.videos:
      return media.where((e) => e.mimeStart == "video").toList();
  }
}

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
