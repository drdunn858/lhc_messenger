import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livehelp/model/model.dart';
import 'package:livehelp/pages/chat/audio_recorder_controller.dart';
import 'package:livehelp/pages/chat/text_wdiget_.dart';
import 'package:livehelp/services/server_repository.dart';
import 'package:livehelp/utils/function_utils.dart';
import 'package:rxdart/subjects.dart';

//a class which contains the text-box for message, attach file button, audio record and
//send message button
class SendMessageRowWidget extends StatefulWidget {
  const SendMessageRowWidget({
    required Key key,
    required this.chat,
    required this.server,
    required this.isOwnerOfChat,
    required this.submitMessage,
  }) : super(key: key);
  final Chat? chat;
  final Server server;
  final bool isOwnerOfChat;
  final Function(String messaage,{String? sender,}) submitMessage;
  @override
  State<SendMessageRowWidget> createState() => _SendMessageRowWidgetState();
}

class _SendMessageRowWidgetState extends State<SendMessageRowWidget> {
  //Audio recorder controller
  late AudioRecorderController _audioConrtoller;
  String? recordedFilePath;
  bool isRecording = false;
  Timer? _timer;
  int dummyValue = 0;
  TextEditingController textController = TextEditingController();
  bool isDepartmentWhatsapp = true;
  ServerRepository? serverRepository;
  final _writingSubject = PublishSubject<String>();
  bool isUploading = false;
  bool isWhisperModeOn = false;
  @override
  void initState() {
    super.initState();
    _audioConrtoller = AudioRecorderController();
    serverRepository = RepositoryProvider.of<ServerRepository>(
        context); //subject.stream.debounce(new Duration(milliseconds: 300)).listen(_textChanged);
    // _writingSubject.stream.listen(_textChanged);
    // if (widget.chat?.department_name != null) {
    //   String depName = widget.chat!.department_name!.toLowerCase();
    //   if (depName.toLowerCase().startsWith('w')) {
    //     isDepartmentWhatsapp = true;
    //   }
    // }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioConrtoller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Visibility(visible: isUploading, child: UploadingWidget()),
        Row(
          children: [
            IconButton(onPressed: () {
              setState(() {
                isWhisperModeOn=!isWhisperModeOn;
              });
            },icon: Icon(isWhisperModeOn?Icons.hearing:Icons.hearing_disabled,),
             color: isWhisperModeOn? Colors.blue:Colors.black54,),
            SizedBox(
              width: 5,
            ),
            Flexible(
              child: TextField(
                controller: textController,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                maxLines: null,
                enableInteractiveSelection: true,
                onChanged: (txt) => (_writingSubject.add(txt)),
                onSubmitted: (value) {
                  widget.submitMessage(value,sender: isWhisperModeOn?"system":"operator");
                },
                decoration: widget.isOwnerOfChat
                    ? const InputDecoration(
                        hintText: "Enter a message to send",
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none)
                    : const InputDecoration(
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        hintMaxLines: 1,
                        hintText: "You are not the owner of this chat",
                        hintStyle: 
                        TextStyle(fontSize: 14)
                      ),
              ),
            ),
            //Functionality to send documents in chat
            Container(
              child: IconButton(
                icon: Icon(
                  isRecording ? Icons.cancel : Icons.attach_file,
                  color: isRecording ? Colors.red : Colors.black,
                ),
                onPressed: () async {
                  try {
                    if (isRecording) {
                      await cancelRecording();
                    } else {
                      FilePickerResult? result =
                          await FilePicker.platform.pickFiles();
                      if (result != null) {
                        File file = File(result.files.single.path!);
                        log(file.path);
                        setState(() {
                          isUploading = true;
                        });
                        final uploadedFileResult = await serverRepository!
                            .uploadFile(widget.server, file);

                        if (uploadedFileResult != null) {
                          log(uploadedFileResult.toString());
                          //send file to user
                          widget.submitMessage(FunctionUtils.buildFileMessage(
                              updateFileResponse: uploadedFileResult));
                        }
                        setState(() {
                          isUploading = false;
                        });
                        // widget.onUploadCompleted();
                      } else {
                        //file pick operation cancelled
                      }
                    }
                  } catch (e) {
                    setState(() {
                      isUploading = false;
                    });
                    FunctionUtils.showErrorMessage(
                        message: "Error:${e.toString()}");
                    // widget.onUploadCompleted();
                  }
                },
              ),
            ),
            //Mic Functionality for sending voice messages
            Container(
              child: IconButton(
                icon: Icon(
                  isRecording ? Icons.stop : Icons.mic,
                  color: isRecording ? Colors.red : Colors.black,
                ),
                onPressed: () {
                  if (isRecording) {
                    stopRecording();
                  } else {
                    startRecording();
                  }
                },
              ),
            ),
            Container(
              child: isRecording
                  ? Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: UpdatingTextWidget(),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () {
                        if (textController.text.isNotEmpty) {
                        widget.submitMessage(textController.text,sender: isWhisperModeOn?"system":"operator");
                          textController.clear();
                        }
                      }),
            ),
          ],
        ),
      ],
    );
  }

  //start recording
  Future<void> startRecording() async {
    if (isRecording) {
      return;
    }
    if (await _audioConrtoller.hasPermission()) {
      // Start recording and handle the timer for the 30-second limit
      await _audioConrtoller.startRecording(
          fileName: 'testRecording$dummyValue',
          isDepartmentWhatsapp: isDepartmentWhatsapp);
      setState(() {
        isRecording = true;
      });
      // Automatically stop recording after 30 seconds
      _timer = Timer(Duration(seconds: 30), () {
        stopRecording();
      });
    } else {
      FunctionUtils.showErrorMessage(
          message: "Please grant mic permission front settings to continue");
    }
  }

  // This function will stop the recording process and send the audio message to user.....
  Future<void> stopRecording() async {
    try {
      if (isRecording) {
        // Stop the recording using the audio controller
        final path = await _audioConrtoller
            .stopRecording(); // This path will now directly be an MP3 file
        dummyValue++;
        // Check if the recorded file exists before proceeding
        if (path != null) {
          final recordedFile = File(path); // Ensure the path is not null
          if (await recordedFile.exists()) {
            log('Recorded WAV file saved at: ${recordedFile.path}');
            setState(() {
              recordedFilePath =
                  recordedFile.path; // Update the recorded file path to MP3
              isRecording = false; // Update recording status
              isUploading = true;
            });

            var uploadedFile = await serverRepository!.uploadFile(
                widget.server, recordedFile,
                chatId: widget.chat?.id,);

            //uploaded file will be null if uploading failed
            if (uploadedFile != null) {
              log(
                uploadedFile.toString(),
              );
              String fileMessage = FunctionUtils.buildFileMessage(
                  updateFileResponse: uploadedFile);
              log(widget.chat?.department_name ?? "Null Depart");
              widget.submitMessage(fileMessage);
            } else {}
            setState(() {
              isUploading = false;
            });
            recordedFile.delete();
          }
        } else {
          log('Recorded file does not exist: $path');
          FunctionUtils.showErrorMessage(
              message: "Recorded file not saved! Try again");
        }
      }

      _timer?.cancel(); // Cancel the timer if recording is manually stopped
    } catch (e) {
      setState(() {
        isUploading = false;
      });
      FunctionUtils.showErrorMessage(message: "Error:${e.toString()}");
      // widget.onUploadCompleted();
    }
  } //cancel the recordings and set isRecording false

  Future<void> cancelRecording() async {
    _timer?.cancel(); // Cancel the timer
    await _audioConrtoller.cancelRecording();
    setState(() {
      isRecording = false;
    });
  }
}

// a widget which will be shown when an audio/image or file is being uploaded in chat
class UploadingWidget extends StatelessWidget {
  const UploadingWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        "Uploading ......",
        style: TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
