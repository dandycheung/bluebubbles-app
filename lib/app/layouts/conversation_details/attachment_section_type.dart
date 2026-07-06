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

enum MediaSenderFilterKind { any, fromYou, fromOthers, participant }

class MediaSenderFilter {
  final MediaSenderFilterKind kind;
  final Handle? participant;

  const MediaSenderFilter._(this.kind, this.participant);

  const MediaSenderFilter.any() : this._(MediaSenderFilterKind.any, null);
  const MediaSenderFilter.fromYou() : this._(MediaSenderFilterKind.fromYou, null);
  const MediaSenderFilter.fromOthers() : this._(MediaSenderFilterKind.fromOthers, null);
  const MediaSenderFilter.participant(Handle handle) : this._(MediaSenderFilterKind.participant, handle);

  bool get isActive => kind != MediaSenderFilterKind.any;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaSenderFilter &&
        other.kind == kind &&
        other.participant?.address == participant?.address;
  }

  @override
  int get hashCode => Object.hash(kind, participant?.address);
}

bool attachmentMatchesSenderFilter(Attachment attachment, MediaSenderFilter filter) {
  if (!filter.isActive) return true;

  final message = attachment.message.target;
  if (message == null) return false;

  switch (filter.kind) {
    case MediaSenderFilterKind.any:
      return true;
    case MediaSenderFilterKind.fromYou:
      return message.isFromMe == true;
    case MediaSenderFilterKind.fromOthers:
      return message.isFromMe != true;
    case MediaSenderFilterKind.participant:
      final participant = filter.participant;
      if (participant == null) return true;
      final messageHandle = message.handleRelation.target;
      if (messageHandle != null) {
        return messageHandle.address == participant.address ||
            (participant.originalROWID != null && messageHandle.originalROWID == participant.originalROWID);
      }
      return participant.originalROWID != null && message.handleId == participant.originalROWID;
  }
}

List<Attachment> applyMediaFilters(
  List<Attachment> media, {
  required MediaFilter typeFilter,
  required MediaSenderFilter senderFilter,
}) {
  final byType = filterMedia(media, typeFilter);
  if (!senderFilter.isActive) return byType;
  return byType.where((e) => attachmentMatchesSenderFilter(e, senderFilter)).toList();
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
