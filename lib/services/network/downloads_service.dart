import 'package:bluebubbles/utils/file_utils.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;
import 'package:path/path.dart';
import 'package:universal_io/io.dart';

/// Download state for attachments
enum AttachmentDownloadState {
  /// Waiting in queue to start downloading
  queued,

  /// Currently downloading from server
  downloading,

  /// Download complete, now processing (EXIF extraction, format conversion, etc.)
  processing,

  /// Download and processing complete
  complete,

  /// Download or processing failed
  error,
}

/// Get an instance of our [AttachmentDownloadService]
// ignore: non_constant_identifier_names
AttachmentDownloadService AttachmentDownloader = Get.isRegistered<AttachmentDownloadService>()
    ? Get.find<AttachmentDownloadService>()
    : Get.put(AttachmentDownloadService());

class AttachmentDownloadService extends GetxService {
  final RxList<String> downloaders = <String>[].obs;
  final Map<String, List<AttachmentDownloadController>> _downloaders = {};

  AttachmentDownloadController? getController(String? guid) {
    return _downloaders.values.flattened.firstWhereOrNull((element) => element.attachment.guid == guid);
  }

  AttachmentDownloadController startDownload(Attachment a, {Function(PlatformFile)? onComplete, Function? onError}) {
    return Get.put(
        AttachmentDownloadController(
          attachment: a,
          onComplete: onComplete,
          onError: onError,
        ),
        tag: a.guid!);
  }

  void _addToQueue(AttachmentDownloadController downloader) {
    downloaders.add(downloader.attachment.guid!);
    final chatGuid = downloader.attachment.message.target?.chat.target?.guid ?? "unknown";
    if (_downloaders.containsKey(chatGuid)) {
      _downloaders[chatGuid]!.add(downloader);
    } else {
      _downloaders[chatGuid] = [downloader];
    }
    _fetchNext();
  }

  void _removeFromQueue(AttachmentDownloadController downloader) {
    downloaders.remove(downloader.attachment.guid!);
    final chatGuid = downloader.attachment.message.target?.chat.target?.guid ?? "unknown";
    _downloaders[chatGuid]!.removeWhere((e) => e.attachment.guid == downloader.attachment.guid);
    if (_downloaders[chatGuid]!.isEmpty) _downloaders.remove(chatGuid);
    Get.delete<AttachmentDownloadController>(tag: downloader.attachment.guid!);
    _fetchNext();
  }

  void _fetchNext() {
    final maxDownloads = SettingsSvc.settings.maxConcurrentDownloads.value;
    if (_downloaders.values.flattened.where((e) => e.state.value == AttachmentDownloadState.downloading).length <
        maxDownloads) {
      AttachmentDownloadController? activeChatDownloader;
      // first check if we have an active chat that needs downloads, if so prioritize that chat
      if (ChatsSvc.activeChat != null && _downloaders.containsKey(ChatsSvc.activeChat!.chat.guid)) {
        activeChatDownloader = _downloaders[ChatsSvc.activeChat!.chat.guid]!
            .firstWhereOrNull((e) => e.state.value == AttachmentDownloadState.queued);
        activeChatDownloader?.fetchAttachment();
      }
      // otherwise just grab a random attachment that needs fetching
      if (activeChatDownloader == null) {
        _downloaders.values.flattened
            .firstWhereOrNull((e) => e.state.value == AttachmentDownloadState.queued)
            ?.fetchAttachment();
      }
    }
  }
}

class AttachmentDownloadController extends GetxController {
  final Attachment attachment;
  final List<Function(PlatformFile)> completeFuncs = [];
  final List<Function> errorFuncs = [];
  final RxnNum progress = RxnNum();
  final Rxn<PlatformFile> file = Rxn<PlatformFile>();
  final Rx<AttachmentDownloadState> state = Rx<AttachmentDownloadState>(AttachmentDownloadState.queued);
  Stopwatch stopwatch = Stopwatch();

  AttachmentDownloadController({
    required this.attachment,
    Function(PlatformFile)? onComplete,
    Function? onError,
  }) {
    if (onComplete != null) completeFuncs.add(onComplete);
    if (onError != null) errorFuncs.add(onError);
  }

  @override
  void onInit() {
    AttachmentDownloader._addToQueue(this);
    super.onInit();
  }

  Future<void> fetchAttachment() async {
    if (attachment.guid == null || attachment.guid!.contains("temp")) return;
    state.value = AttachmentDownloadState.downloading;
    stopwatch.start();

    // Mark as not downloaded while downloading (handles re-downloads)
    attachment.isDownloaded = false;

    // For web, download to memory. For native platforms, write directly to disk
    final savePath = kIsWeb ? null : attachment.path;

    var response = await HttpSvc.downloadAttachment(
      attachment.guid!,
      savePath: savePath,
      onReceiveProgress: (count, total) => setProgress(kIsWeb ? (count / total) : (count / attachment.totalBytes!)),
    ).catchError((err) async {
      if (!kIsWeb && savePath != null) {
        File file = File(savePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      for (Function f in errorFuncs) {
        f.call();
      }

      state.value = AttachmentDownloadState.error;
      AttachmentDownloader._removeFromQueue(this);
      return Response(requestOptions: RequestOptions(path: ''));
    });

    Logger.info("Finished downloading attachment");
    if (response.statusCode != 200) return;

    attachment.webUrl = response.requestOptions.path;
    stopwatch.stop();
    Logger.info("Attachment downloaded in ${stopwatch.elapsedMilliseconds} ms");

    // Set processing state to show indeterminate spinner
    progress.value = 1.0;
    state.value = AttachmentDownloadState.processing;

    // Handle web-specific processing (bytes in memory)
    Uint8List? bytes;
    if (kIsWeb) {
      if (attachment.mimeType == "image/gif") {
        bytes = await fixSpeedyGifs(response.data);
      } else {
        bytes = response.data;
      }
      attachment.bytes = bytes;
    } else {
      // For native platforms, file is already written to disk
      // Handle GIF optimization if needed
      if (attachment.mimeType == "image/gif" && savePath != null) {
        final fileBytes = await File(savePath).readAsBytes();
        final optimizedBytes = await fixSpeedyGifs(fileBytes);
        await File(savePath).writeAsBytes(optimizedBytes);
      }
    }

    // Load image properties before displaying (so UI shows correct dimensions immediately)
    if (!kIsWeb && attachment.mimeStart == "image") {
      try {
        await AttachmentsSvc.loadImageProperties(attachment, actualPath: attachment.path);
      } catch (ex) {
        Logger.warn("Failed to load image properties", error: ex);
      }
    }

    // Create the PlatformFile
    file.value = PlatformFile(
      name: attachment.transferName!,
      path: kIsWeb ? null : attachment.path,
      size: kIsWeb ? bytes!.length : await File(attachment.path).length(),
      bytes: kIsWeb ? bytes : null,
    );

    // Mark attachment as downloaded and save to database
    attachment.isDownloaded = true;
    await attachment.saveAsync(attachment.message.target);

    // Mark as complete
    state.value = AttachmentDownloadState.complete;

    // Call completion callbacks while controller is still registered
    for (Function f in completeFuncs) {
      f.call(file.value);
    }

    // Finally, remove the downloader from queue
    AttachmentDownloader._removeFromQueue(this);

    // Desktop-specific handling
    if (kIsDesktop && attachment.bytes != null) {
      File _file = await File(attachment.path).create(recursive: true);
      await _file.writeAsBytes(attachment.bytes!.toList());
    }

    // Auto-save handling
    if (SettingsSvc.settings.autoSave.value &&
        !kIsWeb &&
        !kIsDesktop &&
        !(attachment.isOutgoing ?? false) &&
        !(attachment.message.target?.isInteractive ?? false)) {
      if (attachment.mimeType?.startsWith("image") ?? false) {
        await AttachmentsSvc.saveToDisk(file.value!, isAutoDownload: true);
      } else if (file.value?.bytes != null) {
        await File(join(await FilesystemSvc.downloadsDirectory, file.value!.name)).writeAsBytes(file.value!.bytes!);
      }
    }
  }

  void setProgress(double value) {
    if (value.isNaN) {
      value = 0;
    } else if (value.isInfinite) {
      value = 1.0;
    } else if (value.isNegative) {
      value = 0;
    }

    progress.value = value.clamp(0, 1);
  }
}
