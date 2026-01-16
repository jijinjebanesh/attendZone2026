import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:swipe_to/swipe_to.dart';

// --- THEME CONSTANTS ---
const Color kOrange = Color(0xFFFF9800);
const Color kOrangeDark = Color(0xFFF57C00);
const Color kOrangeLight = Color(0xFFFFE0B2);

class ChatScreen extends StatefulWidget {
  final String projectName;
  final String senderEmail;

  const ChatScreen({
    super.key,
    required this.projectName,
    required this.senderEmail,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  late IO.Socket socket;
  // UPDATE YOUR IP ADDRESS HERE
  final String _baseUrl = "http://192.168.137.1:5000";
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();

  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isTyping = false;
  String? _typingUser;
  Map<String, dynamic>? _replyingTo;
  Timer? _typingDebounce;
  Map<String, double> _uploadProgress = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectSocket();
    _fetchHistory();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    socket.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _typingDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    if (bottomInset > 0) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToBottom();
      });
    }
  }

  void _connectSocket() {
    socket = IO.io(
      _baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      print("Connected to socket");
      socket.emit("authenticate", widget.senderEmail);
      socket.emit("joinProject", widget.projectName);
    });

    socket.on("newMessage", (data) {
      if (mounted) {
        setState(() {
          // This matches the tempId sent from backend now
          final tempIndex = _messages.indexWhere(
            (m) => m['tempId'] == data['tempId'],
          );
          if (tempIndex != -1) {
            _messages[tempIndex] = data; // REPLACES TEMP ID WITH REAL ID
            _uploadProgress.remove(data['tempId']);
          } else {
            _messages.add(data);
          }
        });
        _scrollToBottom();
        _markAsRead(data['_id']);
      }
    });

    socket.on("typing", (data) {
      if (data['email'] != widget.senderEmail && mounted) {
        setState(() {
          _typingUser = data['isTyping'] ? data['email'] : null;
        });
      }
    });

    socket.on("reactionUpdate", (data) => _handleReactionUpdate(data));
    socket.on("pollUpdated", (data) => _handlePollUpdate(data));
    socket.on("messageDeleted", (data) => _handleMessageDeleted(data));
    socket.on("messageRead", (data) {
      final index = _messages.indexWhere((m) => m['_id'] == data['messageId']);
      if (index != -1) {
        setState(() {
          final readBy = List.from(_messages[index]['readBy'] ?? []);
          final alreadyExists = readBy.any((r) {
            if (r is Map) return r['reader'] == data['reader'];
            if (r is String) return r == data['reader'];
            return false;
          });

          if (!alreadyExists) {
            readBy.add({
              'reader': data['reader'],
              'timestamp':
                  data['timestamp'] ?? DateTime.now().toIso8601String(),
            });
            _messages[index]['readBy'] = readBy;
          }
        });
      }
    });
  }

  Future<void> _fetchHistory() async {
    try {
      final response = await http.post(
        Uri.parse("$_baseUrl/api/v1/chat/messages"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": widget.senderEmail}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final projectMessages = data
            .where((m) => m['project_name'] == widget.projectName)
            .toList();

        projectMessages.sort((a, b) {
          DateTime dateA = DateTime.parse(
            a['timestamp'] ?? DateTime.now().toIso8601String(),
          );
          DateTime dateB = DateTime.parse(
            b['timestamp'] ?? DateTime.now().toIso8601String(),
          );
          return dateA.compareTo(dateB);
        });

        if (mounted) {
          setState(() {
            _messages = projectMessages;
            _isLoading = false;
          });
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToBottom(),
          );
          _markAllUnreadAsRead();
        }
      }
    } catch (e) {
      print("Error fetching history: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _markAllUnreadAsRead() {
    for (final message in _messages) {
      final messageId = message['_id'];
      final readBy = message['readBy'] as List? ?? [];
      final isAlreadyRead =
          readBy.isNotEmpty &&
          readBy.any((r) {
            if (r is Map) return r['reader'] == widget.senderEmail;
            if (r is String) return r == widget.senderEmail;
            return false;
          });

      if (!isAlreadyRead && message['sender'] != widget.senderEmail) {
        _markAsRead(messageId);
      }
    }
  }

  void _handleReactionUpdate(Map<String, dynamic> data) {
    final index = _messages.indexWhere((m) => m['_id'] == data['messageId']);
    if (index != -1) {
      setState(() {
        List reactions = List.from(_messages[index]['reactions'] ?? []);

        if (data['action'] == 'added') {
          reactions.add({
            'sender': data['sender'],
            'emoji': data['reaction'],
            '_id': "temp_${DateTime.now().millisecondsSinceEpoch}",
          });
        } else if (data['action'] == 'updated') {
          // Handle reaction change (e.g. like changed to heart)
          final reactionIdx = reactions.indexWhere(
            (r) => r['sender'] == data['sender'],
          );
          if (reactionIdx != -1) {
            reactions[reactionIdx]['emoji'] = data['reaction'];
          }
        } else if (data['action'] == 'removed') {
          reactions.removeWhere(
            (r) =>
                r['sender'] == data['sender'] && r['emoji'] == data['reaction'],
          );
        }
        _messages[index]['reactions'] = reactions;
      });
    }
  }

  void _handlePollUpdate(Map<String, dynamic> data) {
    final index = _messages.indexWhere((m) => m['_id'] == data['pollId']);
    if (index != -1) {
      setState(() {
        _messages[index] = data['updatedPoll'];
      });
    }
  }

  void _handleMessageDeleted(Map<String, dynamic> data) {
    final index = _messages.indexWhere((m) => m['_id'] == data['messageId']);
    if (index != -1) {
      setState(() {
        _messages[index]['status'] = 'deleted';
        _messages[index]['message'] = "[This message was deleted]";
      });
    }
  }

  void _sendMessage({
    String? type,
    String? content,
    Map<String, dynamic>? metadata,
  }) {
    if ((_textController.text.trim().isEmpty && type == null) || type == 'poll')
      return;

    final msgContent = content ?? _textController.text.trim();
    final now = DateTime.now();
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();

    final payload = {
      "project_name": widget.projectName,
      "sender": widget.senderEmail,
      "message": msgContent,
      "date": DateFormat('yyyy-MM-dd').format(now),
      "time": DateFormat('HH:mm:ss').format(now),
      "tempId": tempId,
      "replyTo": _replyingTo?['_id'],
      "caption": null,
      if (metadata != null) ...metadata,
    };

    setState(() {
      _messages.add({
        ...payload,
        '_id': tempId, // Temporary ID set here
        'type': type ?? 'text',
        'metadata': metadata,
        'status': 'sending',
        'readBy': [],
        'reactions': [],
      });
    });

    _scrollToBottom();

    if (type == 'file' || type == 'image') {
      _simulateUploadProgress(tempId);
    }

    socket.emit("sendMessage", payload);

    _textController.clear();
    setState(() => _replyingTo = null);
    _stopTyping();
  }

  // --- FIX 1: Removed Navigator.pop(context) from here ---
  void _sendReaction(String messageId, String emoji) {
    socket.emit("sendReaction", {
      "project_name": widget.projectName,
      "messageId": messageId,
      "sender": widget.senderEmail,
      "reaction": emoji,
    });
    // NO POP HERE! Context is managed by the modal's onTap
  }

  void _deleteMessage(String messageId) {
    // Basic check to ensure we aren't deleting a pending message with a temp ID (numeric only string)
    // Real Mongo IDs are 24 hex characters. Simple heuristic check:
    if (messageId.length < 15 && int.tryParse(messageId) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please wait for message to finish sending"),
        ),
      );
      return;
    }

    socket.emit("deleteMessage", {
      "messageId": messageId,
      "project_name": widget.projectName,
      "deleter": widget.senderEmail,
    });
    Navigator.pop(context);
  }

  void _votePoll(String pollId, int optionIndex) {
    socket.emit("voteInPoll", {
      "pollId": pollId,
      "voter": widget.senderEmail,
      "selectedOptions": [optionIndex],
      "project_name": widget.projectName,
    });
  }

  void _markAsRead(String messageId) {
    socket.emit("markAsRead", {
      "messageId": messageId,
      "reader": widget.senderEmail,
    });
  }

  void _onTextChanged(String text) {
    if (!_isTyping) {
      _isTyping = true;
      socket.emit("typing", {
        "project_name": widget.projectName,
        "email": widget.senderEmail,
        "isTyping": true,
      });
    }
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), _stopTyping);
  }

  void _stopTyping() {
    _isTyping = false;
    socket.emit("typing", {
      "project_name": widget.projectName,
      "email": widget.senderEmail,
      "isTyping": false,
    });
  }

  Future<void> _pickAndSendFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      File file = File(result.files.single.path!);
      List<int> imageBytes = await file.readAsBytes();
      String base64File = base64Encode(imageBytes);

      _sendMessage(
        type: 'file',
        content: "file:$base64File",
        metadata: {
          "fileName": result.files.single.name,
          "fileSize": result.files.single.size,
          "fileType": "application/octet-stream",
          "fileExtension": _getFileExtension(result.files.single.name),
        },
      );
    }
  }

  Future<void> _pickAndSendImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      List<int> imageBytes = await image.readAsBytes();
      String base64Image = base64Encode(imageBytes);
      _sendMessage(type: 'image', content: "image:$base64Image");
    }
  }

  void _simulateUploadProgress(String tempId) {
    setState(() {
      _uploadProgress[tempId] = 0;
    });

    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_uploadProgress.containsKey(tempId)) {
          _uploadProgress[tempId] = (_uploadProgress[tempId]! + 8).clamp(0, 95);
        } else {
          timer.cancel();
        }
      });
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _uploadProgress[tempId] = 100;
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _uploadProgress.remove(tempId);
            });
          }
        });
      }
    });
  }

  String _getFileExtension(String fileName) {
    if (!fileName.contains('.')) return '';
    return fileName.split('.').last.toLowerCase();
  }

  void _showCreatePollDialog() {
    TextEditingController questionCtrl = TextEditingController();
    List<TextEditingController> optionsCtrl = [
      TextEditingController(),
      TextEditingController(),
    ];

    showDialog(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: scheme.surface,
              title: Text("Create Poll", style: TextStyle(color: kOrange)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: questionCtrl,
                      style: TextStyle(color: scheme.onSurface),
                      decoration: InputDecoration(
                        hintText: "Ask a question...",
                        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: kOrange),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    ...List.generate(optionsCtrl.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: TextField(
                          controller: optionsCtrl[index],
                          style: TextStyle(color: scheme.onSurface),
                          decoration: InputDecoration(
                            hintText: "Option ${index + 1}",
                            hintStyle: TextStyle(
                              color: scheme.onSurfaceVariant,
                            ),
                            filled: true,
                            fillColor: scheme.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      );
                    }),
                    TextButton(
                      onPressed: () {
                        setDialogState(() {
                          optionsCtrl.add(TextEditingController());
                        });
                      },
                      child: const Text(
                        "+ Add Option",
                        style: TextStyle(color: kOrange),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Cancel",
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kOrange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (questionCtrl.text.isNotEmpty &&
                        optionsCtrl.every((c) => c.text.isNotEmpty)) {
                      final now = DateTime.now();
                      socket.emit("createPoll", {
                        "project_name": widget.projectName,
                        "sender": widget.senderEmail,
                        "question": questionCtrl.text,
                        "options": optionsCtrl.map((c) => c.text).toList(),
                        "isMultiSelect": false,
                        "date": DateFormat('yyyy-MM-dd').format(now),
                        "time": DateFormat('HH:mm:ss').format(now),
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text("Create"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showAttachmentModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachmentOption(
                  icon: Icons.image,
                  color: Colors.purpleAccent,
                  label: "Gallery",
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendImage();
                  },
                ),
                _AttachmentOption(
                  icon: Icons.insert_drive_file,
                  color: Colors.blueAccent,
                  label: "Document",
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendFile();
                  },
                ),
                _AttachmentOption(
                  icon: Icons.poll,
                  color: kOrange,
                  label: "Poll",
                  onTap: () {
                    Navigator.pop(context);
                    _showCreatePollDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        leading: BackButton(color: scheme.onSurface),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.projectName,
              style: GoogleFonts.inter(
                color: scheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (_typingUser != null)
              Text(
                "$_typingUser is typing...",
                style: GoogleFonts.inter(color: kOrange, fontSize: 12),
              )
            else
              Text(
                "Online",
                style: GoogleFonts.inter(
                  color: Colors.greenAccent,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: scheme.onSurface),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: kOrange))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 20,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg['sender'] == widget.senderEmail;
                      final isFirstInSequence =
                          index == 0 ||
                          _messages[index - 1]['sender'] != msg['sender'];

                      return SwipeTo(
                        onRightSwipe: (details) {
                          setState(() {
                            _replyingTo = msg;
                          });
                        },
                        child: MessageBubble(
                          message: msg,
                          isMe: isMe,
                          isFirstInSequence: isFirstInSequence,
                          onLongPress: () => _handleMessageLongPress(msg, isMe),
                          onVote: (pollId, idx) => _votePoll(pollId, idx),
                          currentUserEmail: widget.senderEmail,
                          uploadProgress: _uploadProgress[msg['tempId']] ?? 0,
                        ),
                      );
                    },
                  ),
          ),
          _buildInputArea(scheme),
        ],
      ),
    );
  }

  Widget _buildInputArea(ColorScheme scheme) {
    return SafeArea(
      top: false,
      child: Container(
        color: scheme.surface,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingTo != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: scheme.background,
                  border: Border(left: BorderSide(color: kOrange, width: 4)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Replying to ${_replyingTo!['sender']}",
                            style: const TextStyle(
                              color: kOrange,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _replyingTo!['type'] == 'text'
                                ? _replyingTo!['message']
                                : '[Attachment]',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: scheme.onSurfaceVariant,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _replyingTo = null),
                    ),
                  ],
                ),
              ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: kOrange,
                    size: 26,
                  ),
                  onPressed: _showAttachmentModal,
                ),

                Expanded(
                  child: TextField(
                    controller: _textController,
                    onChanged: _onTextChanged,
                    style: TextStyle(color: scheme.onSurface),
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                      filled: true,
                      fillColor: scheme.background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                GestureDetector(
                  onTap: _sendMessage,
                  child: const CircleAvatar(
                    radius: 20,
                    backgroundColor: kOrange,
                    child: Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleMessageLongPress(Map<String, dynamic> msg, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: scheme.outline.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...[
                        ("👍", "Thumbs Up"),
                        ("❤️", "Love"),
                        ("😂", "Laugh"),
                        ("😮", "Shocked"),
                        ("😢", "Sad"),
                        ("🔥", "Fire"),
                      ].map((emoji) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () {
                              _sendReaction(msg['_id'], emoji.$1);
                              Navigator.pop(context); // This closes the modal
                            },
                            child: Tooltip(
                              message: emoji.$2,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: scheme.background.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  emoji.$1,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildContextMenuTile(
                      icon: Icons.reply,
                      label: "Reply",
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => _replyingTo = msg);
                      },
                      scheme: scheme,
                    ),
                    if (msg['type'] == 'text')
                      _buildContextMenuTile(
                        icon: Icons.content_copy,
                        label: "Copy",
                        onTap: () {
                          Navigator.pop(context);
                        },
                        scheme: scheme,
                      ),
                    if (isMe)
                      _buildContextMenuTile(
                        icon: Icons.delete_outline,
                        label: "Delete",
                        isDelete: true,
                        onTap: () => _deleteMessage(msg['_id']),
                        scheme: scheme,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContextMenuTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ColorScheme scheme,
    bool isDelete = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: isDelete ? Colors.red : kOrange, size: 22),
              const SizedBox(width: 16),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: isDelete ? Colors.red : scheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ... Keep MessageBubble and _AttachmentOption classes as they were ...
class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool isFirstInSequence;
  final VoidCallback onLongPress;
  final Function(String, int) onVote;
  final String currentUserEmail;
  final double uploadProgress;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isFirstInSequence,
    required this.onLongPress,
    required this.onVote,
    required this.currentUserEmail,
    this.uploadProgress = 0,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (message['status'] == 'deleted') {
      return _buildDeletedBubble(scheme);
    }

    Widget content;
    switch (message['type']) {
      case 'image':
        content = _buildImage(scheme);
        break;
      case 'file':
        content = _buildFile(scheme);
        break;
      case 'poll':
        content = _buildPoll(scheme);
        break;
      default:
        content = _buildText(scheme);
    }

    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        margin: EdgeInsets.only(
          top: isFirstInSequence ? 8 : 2,
          left: isMe ? 50 : 0,
          right: isMe ? 0 : 50,
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Replied Message Preview
            if (message['replyTo'] != null && message['repliedMessage'] != null)
              Container(
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isMe
                      ? kOrangeLight.withOpacity(0.5)
                      : scheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(
                      color: isMe ? Colors.orange : kOrange,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  "${message['repliedMessage']['sender']}: ${message['repliedMessage']['type'] == 'text' ? message['repliedMessage']['message'] : '[Attachment]'}",
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe
                        ? scheme.onSurface.withOpacity(0.5)
                        : scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // Main Bubble
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? kOrange : scheme.surfaceVariant,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe && isFirstInSequence)
                    Text(
                      message['sender'].split('@')[0],
                      style: const TextStyle(
                        color: kOrange,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  content,
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _formatTime(message['time']),
                        style: TextStyle(
                          fontSize: 9,
                          color: isMe
                              ? Colors.white.withOpacity(0.7)
                              : scheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 12,
                          color: (message['readBy'] as List).length > 1
                              ? Colors.blue
                              : Colors.white.withOpacity(0.5),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Reactions
            if (message['reactions'] != null &&
                (message['reactions'] as List).isNotEmpty)
              Transform.translate(
                offset: const Offset(0, -10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outline, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: (message['reactions'] as List)
                        .take(3)
                        .map<Widget>(
                          (r) => Text(
                            r['emoji'] ?? '',
                            style: const TextStyle(fontSize: 12),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeletedBubble(ColorScheme scheme) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              "This message was deleted",
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildText(ColorScheme scheme) {
    return Text(
      message['message'],
      style: TextStyle(
        color: isMe ? Colors.white : scheme.onSurface,
        fontSize: 15,
      ),
    );
  }

  Widget _buildImage(ColorScheme scheme) {
    if (uploadProgress > 0 && uploadProgress < 100) {
      // Show progress overlay during upload
      return Stack(
        children: [
          Container(
            height: 200,
            width: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.black26,
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(kOrange),
                strokeWidth: 2,
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "${uploadProgress.toStringAsFixed(0)}%",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        message['message'],
        height: 200,
        width: 200,
        fit: BoxFit.cover,
        loadingBuilder: (ctx, child, prog) {
          if (prog == null) return child;
          return Container(
            height: 200,
            width: 200,
            color: Colors.black12,
            child: const Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (ctx, err, stack) =>
            const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }

  Widget _buildFile(ColorScheme scheme) {
    final meta = message['metadata'] ?? {};
    final String fileName = meta['fileName'] ?? 'Unknown File';
    final String size =
        "${((meta['fileSize'] ?? 0) / 1024).toStringAsFixed(1)} KB";
    final String fileExtension = (meta['fileExtension'] ?? '').toLowerCase();

    return InkWell(
      onTap: uploadProgress < 100
          ? null
          : () => _downloadFile(message['message'], fileName),
      child: Stack(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.black12
                      : scheme.background.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getFileIcon(fileExtension),
                  color: _getFileIconColor(fileExtension, isMe, scheme),
                  size: 30,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isMe ? Colors.white : scheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (uploadProgress > 0 && uploadProgress < 100)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: uploadProgress / 100,
                              minHeight: 3,
                              backgroundColor: isMe
                                  ? Colors.white.withOpacity(0.3)
                                  : scheme.background.withOpacity(0.3),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isMe ? Colors.white : kOrange,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${uploadProgress.toStringAsFixed(0)}%",
                            style: TextStyle(
                              color: isMe
                                  ? Colors.white.withOpacity(0.7)
                                  : scheme.onSurfaceVariant,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        size,
                        style: TextStyle(
                          color: isMe
                              ? Colors.white.withOpacity(0.7)
                              : scheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String extension) {
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip;
      case 'mp3':
      case 'wav':
      case 'm4a':
        return Icons.audio_file;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.video_file;
      case 'txt':
        return Icons.text_fields;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileIconColor(String extension, bool isMe, ColorScheme scheme) {
    if (isMe) return Colors.white;

    switch (extension) {
      case 'pdf':
        return Colors.redAccent;
      case 'doc':
      case 'docx':
        return Colors.blueAccent;
      case 'xls':
      case 'xlsx':
        return Colors.greenAccent;
      case 'ppt':
      case 'pptx':
        return Colors.orangeAccent;
      case 'zip':
      case 'rar':
      case '7z':
        return Colors.purpleAccent;
      case 'mp3':
      case 'wav':
      case 'm4a':
        return Colors.pinkAccent;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Colors.cyanAccent;
      default:
        return kOrange;
    }
  }

  Widget _buildPoll(ColorScheme scheme) {
    final List options = message['options'];
    final int totalVotes = options.fold(
      0,
      (sum, item) => sum + (item['voters'] as List).length as int,
    );

    return Container(
      width: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message['question'],
            style: TextStyle(
              color: isMe ? Colors.white : scheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          ...options.asMap().entries.map((entry) {
            final idx = entry.key;
            final opt = entry.value;
            final voters = opt['voters'] as List;
            final count = voters.length;
            final percent = totalVotes == 0 ? 0.0 : count / totalVotes;
            final hasVoted = voters.contains(currentUserEmail);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: InkWell(
                onTap: () => onVote(message['_id'], idx),
                child: Stack(
                  children: [
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isMe
                            ? Colors.white.withOpacity(0.1)
                            : scheme.background.withOpacity(0.5),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percent == 0 ? 0.01 : percent,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: hasVoted
                              ? Colors.green.withOpacity(0.5)
                              : kOrange.withOpacity(0.5),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              opt['text'],
                              style: TextStyle(
                                color: isMe ? Colors.white : scheme.onSurface,
                              ),
                            ),
                            Text(
                              "$count",
                              style: TextStyle(
                                color: isMe ? Colors.white : scheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          Text(
            "$totalVotes votes",
            style: TextStyle(
              color: isMe
                  ? Colors.white.withOpacity(0.7)
                  : scheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? time) {
    if (time == null) return "";
    try {
      final dt = DateFormat("HH:mm:ss").parse(time);
      return DateFormat("h:mm a").format(dt);
    } catch (e) {
      return time;
    }
  }

  Future<void> _downloadFile(String url, String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = "${dir.path}/$fileName";
      await Dio().download(url, savePath);
      OpenFile.open(savePath);
    } catch (e) {
      print("Download error: $e");
    }
  }
}

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
