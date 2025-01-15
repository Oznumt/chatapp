import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'group_chat_page.dart';
import 'group_about_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupsPage extends StatelessWidget {
  const GroupsPage({super.key});

  void _showAddGroupDialog(BuildContext context) {
    final TextEditingController _groupNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add New Group"),
          content: TextField(
            controller: _groupNameController,
            decoration: const InputDecoration(hintText: "Enter group name"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                final String groupName = _groupNameController.text.trim();
                if (groupName.isNotEmpty) {
                  _addGroupToFirestore(groupName);
                  Navigator.pop(context);
                }
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  void _addGroupToFirestore(String groupName) {
    final currentUser = FirebaseAuth.instance.currentUser;
    FirebaseFirestore.instance.collection('groups').add({
      'name': groupName,
      'adminId': currentUser!.uid,
      'members': [currentUser.uid],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void _showDeleteGroupDialog(
      BuildContext context, String groupId, String groupName) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser?.uid != null) {
      FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .get()
          .then((doc) {
        final groupData = doc.data() as Map<String, dynamic>;
        if (groupData['adminId'] == currentUser!.uid) {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text("Delete Group"),
                content: Text(
                    "Are you sure you want to delete the group \"$groupName\"?"),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text("Cancel"),
                  ),
                  TextButton(
                    onPressed: () async {
                      await _deleteGroup(groupId);
                      Navigator.pop(context);
                    },
                    child: const Text("Delete"),
                  ),
                ],
              );
            },
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Only the group creator can delete this group.")),
          );
        }
      });
    }
  }

  Future<void> _deleteGroup(String groupId) async {
    await FirebaseFirestore.instance.collection('groups').doc(groupId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Groups"),
      ),
      body: _buildGroupList(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGroupDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildGroupList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('groups').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No groups available."));
        }

        final groups = snapshot.data!.docs;

        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            return _buildGroupListItem(context, groups[index]);
          },
        );
      },
    );
  }

  Widget _buildGroupListItem(
      BuildContext context, QueryDocumentSnapshot group) {
    final groupData = group.data() as Map<String, dynamic>;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(8.0),
        color: Colors.grey[800],
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('groups')
              .doc(group.id)
              .collection('messages')
              .snapshots(),
          builder: (context, snapshot) {
            int unreadCount = 0;

            if (snapshot.hasData) {
              final messages = snapshot.data!.docs;
              final currentUserId = FirebaseAuth.instance.currentUser!.uid;

              unreadCount = messages
                  .where((message) =>
                      !(message['readBy'] as List<dynamic>)
                          .contains(currentUserId) &&
                      message['senderId'] != currentUserId)
                  .length;
            }

            return ListTile(
              leading: const Icon(Icons.group, color: Colors.white),
              title: Text(
                groupData['name'],
                style: const TextStyle(color: Colors.white),
              ),
              trailing: unreadCount > 0
                  ? CircleAvatar(
                      backgroundColor: Colors.green,
                      radius: 10,
                      child: Text(
                        '$unreadCount',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    )
                  : null,
              onTap: () async {
                final currentUser = FirebaseAuth.instance.currentUser;
                if (groupData['members']?.contains(currentUser!.uid) ?? false) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroupChatPage(
                        groupId: group.id,
                        groupName: groupData['name'],
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroupAboutPage(
                        groupId: group.id,
                        groupName: groupData['name'],
                        adminId: groupData['adminId'],
                      ),
                    ),
                  );
                }
              },
              onLongPress: () {
                _showDeleteGroupDialog(context, group.id, groupData['name']);
              },
            );
          },
        ),
      ),
    );
  }
}
