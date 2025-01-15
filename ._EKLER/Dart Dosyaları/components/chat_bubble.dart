import 'package:flutter/material.dart';
import 'package:chatapp/services/chat/chat_service.dart';
import "package:chatapp/themes/theme_provider.dart";
import "package:provider/provider.dart";

class ChatBubble extends StatelessWidget {
  final String message;
  final String? mediaUrl;
  final bool isCurrentUser;
  final String messageId;
  final String chatRoomID;
  final String userId;
  final String status;

  const ChatBubble({
    super.key,
    required this.message,
    this.mediaUrl,
    required this.isCurrentUser,
    required this.messageId,
    required this.chatRoomID,
    required this.userId,
    required this.status,
  });

  void _showOptions(BuildContext context, String messageId, String userId) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              if (isCurrentUser)
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text("Delete Message"),
                  onTap: () {
                    ChatService().deleteMessage(chatRoomID, messageId);
                    Navigator.pop(context);
                  },
                ),
              if (!isCurrentUser)
                ListTile(
                  leading: const Icon(Icons.report),
                  title: const Text("Report"),
                  onTap: () {
                    Navigator.pop(context);
                    _reportMessage(context, messageId, userId);
                  },
                ),
              if (!isCurrentUser)
                ListTile(
                  leading: const Icon(Icons.block),
                  title: const Text("Block user"),
                  onTap: () {
                    Navigator.pop(context);
                    _blockUser(context, userId);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text("Cancel"),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _reportMessage(BuildContext context, String messageId, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Report Message"),
        content: const Text("Are you sure you want to report this message?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ChatService().reportUser(messageId, userId);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Message reported")),
              );
            },
            child: const Text("Report"),
          ),
        ],
      ),
    );
  }

  void _blockUser(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Block User"),
        content: const Text("Are you sure you want to block this user?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              ChatService().blockUser(userId);
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text("User blocked")));
            },
            child: const Text("Block"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    return GestureDetector(
      onLongPress: () {
        _showOptions(context, messageId, userId);
      },
      child: Column(
        crossAxisAlignment:
            isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (mediaUrl != null)
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
                        mediaUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey,
                            height: 200,
                            width: 200,
                            child: const Icon(Icons.broken_image, size: 50),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    mediaUrl!,
                    height: 250,
                    width: 250,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey,
                        height: 200,
                        width: 200,
                        child: const Icon(Icons.broken_image, size: 50),
                      );
                    },
                  ),
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: isCurrentUser
                  ? (isDarkMode
                      ? Colors.green.shade600
                      : Colors.green.shade500)
                  : (isDarkMode
                      ? Colors.grey.shade800
                      : Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 25),
            child: Text(
              message,
              style: TextStyle(
                color: isCurrentUser
                    ? Colors.white
                    : (isDarkMode ? Colors.white : Colors.black),
              ),
            ),
          ),
          if (isCurrentUser)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 25, left: 25),
              child: Text(
                status == "sent" ? "sent" : "read",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
