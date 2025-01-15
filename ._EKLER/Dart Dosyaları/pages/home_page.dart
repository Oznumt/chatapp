import "package:chatapp/components/my_drawer.dart";
import "package:chatapp/components/user_tile.dart";
import "package:chatapp/pages/chat_page.dart";
import "package:chatapp/services/auth/auth_service.dart";
import "package:chatapp/services/chat/chat_service.dart";
import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";

class HomePage extends StatelessWidget {
  HomePage({super.key});

  final AuthService _authService = AuthService();
  final ChatService chatService = ChatService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Home"),
          elevation: 0,
        ),
        drawer: const MyDrawer(),
        body: _buildUserList());
  }

  Widget _buildUserList() {
    return StreamBuilder(
      stream: chatService.getUsersStreamExceptBlocked(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text("Error");
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text("Loading...");
        }

        return ListView(
          children: snapshot.data!
              .map<Widget>((userData) => _buildUserListItem(userData, context))
              .toList(),
        );
      },
    );
  }

  Widget _buildUserListItem(
      Map<String, dynamic> userData, BuildContext context) {
    if (userData["email"] != _authService.getCurrentUser()!.email) {
      final displayName =
          userData["name"] != "" ? userData["name"] : userData["email"];
      final profileImageUrl = userData['profileImageUrl'] as String?;

      return GestureDetector(
        onLongPress: () =>
            _showBlockUserOptions(context, userData["uid"], userData["email"]),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chat_rooms')
              .doc(_getChatRoomId(userData["uid"]))
              .collection('messages')
              .where('status', isEqualTo: 'sent')
              .where('receiverId',
                  isEqualTo: _authService.getCurrentUser()!.uid)
              .snapshots(),
          builder: (context, snapshot) {
            int unreadCount = 0;

            if (snapshot.hasData) {
              unreadCount = snapshot.data!.docs.length;
            }

            return Stack(
              alignment: Alignment.center,
              children: [
                UserTile(
                  text: displayName,
                  leading: CircleAvatar(
                    backgroundImage: profileImageUrl != null
                        ? NetworkImage(profileImageUrl)
                        : null,
                    child: profileImageUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatPage(
                          receiverEmail: userData["email"],
                          receiverId: userData["uid"],
                        ),
                      ),
                    );
                  },
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 40,
                    child: CircleAvatar(
                      backgroundColor: Colors.green,
                      radius: 10,
                      child: Text(
                        '$unreadCount',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    } else {
      return Container();
    }
  }

  void _showBlockUserOptions(
      BuildContext context, String userId, String email) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.block),
                title: Text("Block $email"),
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

  void _blockUser(BuildContext context, String userId) {
    chatService.blockUser(userId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("User blocked")),
    );
  }

  String _getChatRoomId(String otherUserId) {
    List<String> ids = [_authService.getCurrentUser()!.uid, otherUserId];
    ids.sort();
    return ids.join('_');
  }
}
