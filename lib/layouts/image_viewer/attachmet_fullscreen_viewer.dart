import 'dart:io';

import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/layouts/image_viewer/image_viewer.dart';
import 'package:bluebubbles/layouts/image_viewer/video_viewer.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/attachment_downloader_widget.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import "package:flutter/material.dart";
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class AttachmentFullscreenViewer extends StatefulWidget {
  AttachmentFullscreenViewer({
    Key key,
    this.attachment,
    this.allAttachments,
  }) : super(key: key);
  final List<Attachment> allAttachments;
  final Attachment attachment;

  @override
  _AttachmentFullscreenViewerState createState() =>
      _AttachmentFullscreenViewerState();
}

class _AttachmentFullscreenViewerState
    extends State<AttachmentFullscreenViewer> {
  PageController controller;
  int startingIndex;
  Widget placeHolder;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.allAttachments.length; i++) {
      if (widget.allAttachments[i].guid == widget.attachment.guid) {
        startingIndex = i;
      }
    }

    controller = new PageController(initialPage: startingIndex);
  }

  @override
  Widget build(BuildContext context) {
    placeHolder = ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        height: 150,
        width: 200,
        color: Theme.of(context).accentColor,
      ),
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: PhotoViewGestureDetectorScope(
        child: PhotoViewGallery.builder(
          scrollPhysics:
              AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          itemCount: widget.allAttachments.length,
          builder: (BuildContext context, int index) {
            Attachment attachment = widget.allAttachments[index];
            String mimeType = attachment.mimeType;
            mimeType = mimeType.substring(0, mimeType.indexOf("/"));
            dynamic content = AttachmentHelper.getContent(attachment);

            if (content is File) {
              content = content as File;
              if (mimeType == "image") {
                return PhotoViewGalleryPageOptions.customChild(
                  minScale: PhotoViewComputedScale.contained,
                  child: ImageViewer(
                    attachment: attachment,
                    file: content,
                  ),
                  initialScale: PhotoViewComputedScale.contained,
                );
              } else if (mimeType == "video") {
                return PhotoViewGalleryPageOptions.customChild(
                  minScale: PhotoViewComputedScale.contained,
                  child: VideoViewer(
                    file: content,
                  ),
                  initialScale: PhotoViewComputedScale.contained,
                );
              }
            } else if (content is Attachment) {
              content = content as Attachment;
              return PhotoViewGalleryPageOptions.customChild(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Center(
                      child: AttachmentDownloaderWidget(
                        attachment: attachment,
                        onPressed: () {
                          new AttachmentDownloader(attachment);
                          content = AttachmentHelper.getContent(attachment);
                          setState(() {});
                        },
                        placeHolder: placeHolder,
                      ),
                    ),
                  ],
                ),
              );
            } else if (content is AttachmentDownloader) {
              content = content as AttachmentDownloader;
              if (widget.attachment.mimeType == null)
                return PhotoViewGalleryPageOptions.customChild(
                    child: Container());
              (content as AttachmentDownloader).stream.listen((event) {
                if (event is File) {
                  content = event;
                  if (this.mounted) setState(() {});
                }
              }, onError: (error) {
                content = widget.attachment;
                if (this.mounted) setState(() {});
              });
              return PhotoViewGalleryPageOptions.customChild(
                child: StreamBuilder(
                  stream: content.stream,
                  builder: (BuildContext context, AsyncSnapshot snapshot) {
                    if (snapshot.hasError) {
                      return Text(
                        "Error loading",
                        style: Theme.of(context).textTheme.bodyText1,
                      );
                    }
                    if (snapshot.data is File) {
                      content = snapshot.data;
                      return Container();
                    } else {
                      double progress = 0.0;
                      if (snapshot.hasData) {
                        progress = snapshot.data["Progress"];
                      } else {
                        progress = content.progress;
                      }

                      return Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          placeHolder,
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  CircularProgressIndicator(
                                    value: progress,
                                    backgroundColor: Colors.grey,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                  ),
                                  ((content as AttachmentDownloader)
                                              .attachment
                                              .mimeType !=
                                          null)
                                      ? Container(height: 5.0)
                                      : Container(),
                                  (content.attachment.mimeType != null)
                                      ? Text(
                                          content.attachment.mimeType,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText1,
                                        )
                                      : Container()
                                ],
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                  },
                ),
              );
            } else {
              return PhotoViewGalleryPageOptions.customChild(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Error loading",
                      style: Theme.of(context).textTheme.bodyText1,
                    )
                  ],
                ),
              );
            }
          },
          pageController: controller,
        ),
      ),
    );
  }
}