import 'package:chatapp/components/my_textfield.dart';
import 'package:chatapp/models/group_message.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'group_about_page.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class GroupChatPage extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatPage({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  _GroupChatPageState createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final ImagePicker _imagePicker = ImagePicker();
  FocusNode myFocusNode = FocusNode();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkMembership();
      _markMessagesAsRead();
      _scrollToBottom();
    });
  }

  void _checkMembership() async {
    final groupSnapshot = await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .get();
    final groupData = groupSnapshot.data() as Map<String, dynamic>;

    if (!(groupData['members']?.contains(_currentUser!.uid) ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You are not a member of this group.")),
      );
      Navigator.pop(context);
    }
  }

  void _sendMessage() async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final userData = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    final senderName = userData.data()?['name'] ?? "";

    if (_messageController.text.trim().isNotEmpty) {
      FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .add(GroupMessage(
            senderId: _currentUser!.uid,
            senderEmail: _currentUser.email!,
            senderName: senderName,
            message: _messageController.text.trim(),
            timestamp: Timestamp.now(),
            readBy: [],
          ).toMap());
      _messageController.clear();
      _scrollToBottom();
    }
  }

  void _sendMediaMessage(File file) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final userData = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    final senderName = userData.data()?['name'] ?? "";
    final mediaUrl = await _uploadFile(file, "group_media");

    if (mediaUrl != null) {
      FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .add(GroupMessage(
            senderId: _currentUser!.uid,
            senderEmail: _currentUser.email!,
            senderName: senderName,
            message: '',
            timestamp: Timestamp.now(),
            readBy: [],
            mediaUrl: mediaUrl,
          ).toMap());
    }
    _scrollToBottom();
  }

  void _sendFileMessage(File file) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final userData = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    final senderName = userData.data()?['name'] ?? "";
    final fileUrl = await _uploadFile(file, "group_files");

    if (fileUrl != null) {
      FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .add(GroupMessage(
            senderId: _currentUser!.uid,
            senderEmail: _currentUser.email!,
            senderName: senderName,
            message: '',
            timestamp: Timestamp.now(),
            readBy: [],
            fileUrl: fileUrl,
          ).toMap());
    }
    _scrollToBottom();
  }

  Future<String?> _uploadFile(File file, String folderName) async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final storageRef = _storage.ref('$folderName/$userId/$fileName');
      await storageRef.putFile(file);
      return await storageRef.getDownloadURL();
    } catch (e) {
      print("File upload error: $e");
      return null;
    }
  }

  Future<void> deleteGroupMessage(String groupId, String messageId) async {
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .doc(messageId)
          .delete();
      print("Message deleted: $messageId");
    } catch (e) {
      print("Error deleting message: $e");
    }
  }

  void _showMessageOptions(
      BuildContext context, String messageId, bool isCurrentUser) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              if (isCurrentUser) ...[
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text("Delete Message"),
                  onTap: () {
                    Navigator.pop(context);
                    deleteGroupMessage(widget.groupId, messageId);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cancel),
                  title: const Text("Cancel"),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(seconds: 1),
          curve: Curves.fastEaseInToSlowEaseOut,
        );
      }
    });
  }

  void _markMessagesAsRead() async {
    try {
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .get();

      for (var doc in messagesSnapshot.docs) {
        if (!(doc['readBy'] as List).contains(_currentUser!.uid)) {
          await doc.reference.update({
            'readBy': FieldValue.arrayUnion([_currentUser.uid]),
          });
          print("Message ID ${doc.id} marked as read.");
        }
      }
    } catch (e) {
      print("Error marking messages as read: $e");
    }
  }

  Future<void> _pickMedia() async {
    final pickedFile =
        await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _sendMediaMessage(File(pickedFile.path));
    }
  }

  Future<void> _pickFile() async {
    final pickedFile =
        await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _sendFileMessage(File(pickedFile.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: () async {
              final groupSnapshot = await FirebaseFirestore.instance
                  .collection('groups')
                  .doc(widget.groupId)
                  .get();

              final groupData = groupSnapshot.data() as Map<String, dynamic>;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupAboutPage(
                    groupId: widget.groupId,
                    groupName: widget.groupName,
                    adminId: groupData['adminId'],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No messages yet."));
        }

        final messages = snapshot.data!.docs;

        String? previousDate;

        return ListView.builder(
          controller: _scrollController,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final data = messages[index].data() as Map<String, dynamic>;
            final isCurrentUser = data['senderId'] == _currentUser!.uid;

            final List<String> filteredReadBy =
                (data['readBy'] as List<dynamic>)
                    .where((id) => id != _currentUser.uid)
                    .cast<String>()
                    .toList();

            final messageTimestamp = (data['timestamp'] as Timestamp).toDate();
            final messageTime =
                "${messageTimestamp.hour}:${messageTimestamp.minute.toString().padLeft(2, '0')}";

            final messageDate =
                "${messageTimestamp.year}-${messageTimestamp.month.toString().padLeft(2, '0')}-${messageTimestamp.day.toString().padLeft(2, '0')}";

            bool showDateHeader = false;
            if (previousDate != messageDate) {
              showDateHeader = true;
              previousDate = messageDate;
            }

            final senderDisplayName = data['senderName'] != ""
                ? data['senderName']
                : data['senderEmail'];

            return Column(
              children: [
                if (showDateHeader)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      "${messageTimestamp.day.toString().padLeft(2, '0')}/${messageTimestamp.month.toString().padLeft(2, '0')}/${messageTimestamp.year}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                Align(
                  alignment: isCurrentUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: GestureDetector(
                    onLongPress: isCurrentUser
                        ? () => _showMessageOptions(
                              context,
                              messages[index].id,
                              isCurrentUser,
                            )
                        : null,
                    child: Column(
                      crossAxisAlignment: isCurrentUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (!isCurrentUser)
                          Padding(
                            padding:
                                const EdgeInsets.only(left: 12.0, bottom: 4.0),
                            child: Text(
                              senderDisplayName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        if (data['mediaUrl'] != null)
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      data['mediaUrl'],
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey,
                                          height: 200,
                                          width: 200,
                                          child: const Icon(Icons.broken_image,
                                              size: 50),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8.0),
                              margin: EdgeInsets.only(
                                left: isCurrentUser ? 50 : 10,
                                right: isCurrentUser ? 10 : 50,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Image.network(
                                data['mediaUrl'],
                                height: 250,
                                width: 250,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey,
                                    height: 200,
                                    width: 200,
                                    child: const Icon(Icons.broken_image,
                                        size: 50),
                                  );
                                },
                              ),
                            ),
                          ),
                        if (data['fileUrl'] != null)
                          GestureDetector(
                            onTap: () {
                              print("Open file: ${data['fileUrl']}");
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8.0),
                              margin: EdgeInsets.only(
                                left: isCurrentUser ? 50 : 10,
                                right: isCurrentUser ? 10 : 50,
                              ),
                              child: const Icon(
                                Icons.insert_drive_file,
                                size: 50,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: EdgeInsets.only(
                            top: 5,
                            bottom: 5,
                            left: isCurrentUser ? 50 : 10,
                            right: isCurrentUser ? 10 : 50,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isCurrentUser ? Colors.green : Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            data['message'],
                            style: TextStyle(
                              color:
                                  isCurrentUser ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(
                            right: isCurrentUser ? 10 : 50,
                            left: isCurrentUser ? 50 : 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                messageTime,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              if (isCurrentUser)
                                Text(
                                  "Read by: ${filteredReadBy.length}",
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMessageInput() {
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
            margin: const EdgeInsets.only(right: 25),
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(
                Icons.send_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
