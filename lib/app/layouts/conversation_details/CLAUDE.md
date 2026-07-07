# conversation_details/ — Chat Info Panel

Displayed as a right-side panel on tablet or pushed screen on mobile.

## Main Screen
`conversation_details.dart` — top-level screen
`conversation_attachments.dart` — full-page view for a single attachment category

## Dialogs (`dialogs/`)
- `address_picker.dart` — pick which phone/email address to use for a contact
- `change_name.dart` — rename a group chat
- `timeframe_picker.dart` — date range selector (for media/docs filtering)
- `add_participant.dart` — add a member to a group chat
- `chat_sync_dialog.dart` — progress dialog for re-syncing chat history

## Widgets (`widgets/`)

**Info & Actions**
- `chat_info.dart` — header: avatar, chat name, description
- `chat_options.dart` — action buttons (mute, archive, FaceTime, custom avatar, etc.)
- `participants_list.dart` — group member list
- `contact_tile.dart` — individual participant row (tappable → contact details)

**Shared Media**
- `attachment_section_header.dart` — section label + "Show more" action
- `media_gallery_card.dart` — tappable media card → opens `FullscreenMedia`
- `attachments_loader.dart` — attachment pagination and caching
- `filters/media_filters_sheet.dart` — shared filters bottom sheet

**Shared Content (`sections/`)**
- `sections/media/` — images & videos grid + inline type selector
- `sections/links/` — shared URLs list + search helper
- `sections/documents/` — shared files list + search helper
- `sections/locations/` — shared location messages list
