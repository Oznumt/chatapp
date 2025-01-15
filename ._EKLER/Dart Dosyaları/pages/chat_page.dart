import 'package:chatapp/components/chat_bubble.dart';
import 'package:chatapp/components/my_textfield.dart';
import 'package:chatapp/services/auth/auth_service.dart';
import 'package:chatapp/services/chat/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ChatPage extends StatefulWidget {
  final String receiverEmail;
  final String receiverId;

  const ChatPage({
    super.key,
    required this.receiverEmail,
    required this.receiverId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();

  final ScrollController _scrollController = ScrollController();

  final ImagePicker _imagePicker = ImagePicker();
  FocusNode myFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    markMessagesAsRead();
    myFocusNode.addListener(() {
      if (myFocusNode.hasFocus) {
        Future.delayed(
          const Duration(milliseconds: 750),
          () => scrollDown(),
        );
      }
    });
    Future.delayed(const Duration(milliseconds: 500), () => scrollDown());
  }

  @override
  void dispose() {
    myFocusNode.dispose();
    super.dispose();
  }

  void scrollDown() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(seconds: 1),
        curve: Curves.fastEaseInToSlowEaseOut,
      );
    }
  }

  void sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      await _chatService.sendMessage(
        widget.receiverId,
        _messageController.text,
      );
      _messageController.clear();
    }
    scrollDown();
  }

  void sendMediaMessage(File file) async {
    final mediaUrl = await _chatService.uploadFile(file, "chat_media");
    if (mediaUrl != null) {
      await _chatService.sendMessage(widget.receiverId, "", mediaUrl: mediaUrl);
    }
    scrollDown();
  }

  void sendFileMessage(File file) async {
    final fileUrl = await _chatService.uploadFile(file, "chat_files");
    if (fileUrl != null) {
      await _chatService.sendMessage(widget.receiverId, "", mediaUrl: fileUrl);
    }
    scrollDown();
  }

  void markMessagesAsRead() async {
    String senderId = _authService.getCurrentUser()!.uid;
    List<String> ids = [senderId, widget.receiverId];
    ids.sort();
    String chatRoomID = ids.join("_");

    try {
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection("chat_rooms")
          .doc(chatRoomID)
          .collection("messages")
          .where('receiverId', isEqualTo: senderId)
          .where('status', isEqualTo: 'sent')
          .get();

      for (var doc in messagesSnapshot.docs) {
        await FirebaseFirestore.instance
            .collection("chat_rooms")
            .doc(chatRoomID)
            .collection("messages")
            .doc(doc.id)
            .update({'status': 'read'});
        print("Message ID ${doc.id} marked as read.");
      }
    } catch (e) {
      print("Error marking messages as read: $e");
    }
  }

  Future<void> _pickMedia() async {
    final pickedFile =
        await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      sendMediaMessage(File(pickedFile.path));
    }
  }

  Future<void> _pickFile() async {
    final pickedFile =
        await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      sendFileMessage(File(pickedFile.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.receiverId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text("");
            }

            if (!snapshot.hasData ||
                snapshot.data == null ||
                snapshot.data!.data() == null) {
              return Text(widget.receiverEmail);
            }

            final userData = snapshot.data!.data() as Map<String, dynamic>;
            final displayName = userData["name"] != ""
                ? userData["name"]
                : widget.receiverEmail;
            final profileImageUrl = userData['profileImageUrl'] as String?;

            return Row(
              children: [
                if (profileImageUrl != null)
                  CircleAvatar(
                    backgroundImage: NetworkImage(profileImageUrl),
                  ),
                if (profileImageUrl == null)
                  const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                const SizedBox(width: 10),
                Text(displayName),
              ],
            );
          },
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessageList(),
          ),
          _buildUserInput(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    String senderId = _authService.getCurrentUser()!.uid;

    List<String> ids = [senderId, widget.receiverId];
    ids.sort();
    String chatRoomID = ids.join("_");

    return StreamBuilder(
      stream: _chatService.getMessages(widget.receiverId, senderId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No messages yet."));
        }

        String? previousDate;

        return ListView(
          controller: _scrollController,
          children: snapshot.data!.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            bool isCurrentUser = data['senderId'] == senderId;

            final messageTimestamp = (data['timestamp'] as Timestamp).toDate();
            final messageTime =
                "${messageTimestamp.hour}:${messageTimestamp.minute.toString().padLeft(2, '0')}";
            final messageDate =
                "${messageTimestamp.day.toString().padLeft(2, '0')}/${messageTimestamp.month.toString().padLeft(2, '0')}/${messageTimestamp.year}";

            bool showDateHeader = false;
            if (previousDate != messageDate) {
              showDateHeader = true;
              previousDate = messageDate;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showDateHeader)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Center(
                      child: Text(
                        messageDate,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                Align(
                  alignment: isCurrentUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: isCurrentUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      ChatBubble(
                        message: data["message"],
                        mediaUrl: data["mediaUrl"],
                        isCurrentUser: isCurrentUser,
                        messageId: doc.id,
                        userId: data["senderId"],
                        status: isCurrentUser ? data['status'] : '',
                        chatRoomID: chatRoomID,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 4.0, left: 12.0, right: 12.0),
                        child: Text(
                          messageTime,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildUserInput() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25, top: 10),
      child: Row(
        children: [
          Expanded(
            child: MyTextField(
              hintText: "Type a message",
              obscureText: false,
              controller: _messageController,
              focusNode: myFocusNode,
            ),
          ),
          IconButton(
            onPressed: _pickMedia,
            icon: const Icon(Icons.photo, color: Colors.blueGrey),
          ),
          IconButton(
            onPressed: _pickFile,
            icon: const Icon(Icons.attach_file, color: Colors.blueGrey),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            margin: const EdgeInsets.only(right: 20),
            child: IconButton(
              onPressed: sendMessage,
              icon: const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
