import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupAboutPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String adminId;

  const GroupAboutPage({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.adminId,
  });

  @override
  State<GroupAboutPage> createState() => _GroupAboutPageState();
}

class _GroupAboutPageState extends State<GroupAboutPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _ensureCreatorIsAdmin();
  }

  void _ensureCreatorIsAdmin() async {
    final groupSnapshot =
        await _firestore.collection('groups').doc(widget.groupId).get();
    final groupData = groupSnapshot.data() as Map<String, dynamic>;

    final admins = groupData['admins'] as List<dynamic>? ?? [];
    if (!admins.contains(widget.adminId)) {
      await _firestore.collection('groups').doc(widget.groupId).update({
        'admins': FieldValue.arrayUnion([widget.adminId]),
      });
    }
  }

  void _removeUserFromGroup(String userId) async {
    final groupSnapshot =
        await _firestore.collection('groups').doc(widget.groupId).get();
    final groupData = groupSnapshot.data() as Map<String, dynamic>;
    final admins = List<String>.from(groupData['admins'] ?? []);

    if (admins.contains(userId) || userId == widget.adminId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Admins and the creator cannot remove each other.")),
      );
      return;
    }

    await _firestore.collection('groups').doc(widget.groupId).update({
      'members': FieldValue.arrayRemove([userId]),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("User removed from group.")),
    );
  }

  void _leaveGroup() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      final groupSnapshot =
          await _firestore.collection('groups').doc(widget.groupId).get();
      final groupData = groupSnapshot.data() as Map<String, dynamic>;
      final admins = List<String>.from(groupData['admins'] ?? []);

      if (admins.contains(currentUser.uid) && admins.length == 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text("You are the only admin and cannot leave the group.")),
        );
        return;
      }

      if (admins.contains(currentUser.uid)) {
        await _firestore.collection('groups').doc(widget.groupId).update({
          'admins': FieldValue.arrayRemove([currentUser.uid]),
        });
      }

      await _firestore.collection('groups').doc(widget.groupId).update({
        'members': FieldValue.arrayRemove([currentUser.uid]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You left the group.")),
      );

      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text("About: ${widget.groupName}"),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('groups').doc(widget.groupId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("Group data not found"));
          }

          final groupData = snapshot.data!.data() as Map<String, dynamic>;
          final members = groupData['members'] as List<dynamic>? ?? [];
          final admins = groupData['admins'] as List<dynamic>? ?? [];

          final isMember = members.contains(currentUser?.uid);
          final isAdmin = currentUser != null &&
              (currentUser.uid == widget.adminId ||
                  admins.contains(currentUser.uid));

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final userId = members[index];
                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('users').doc(userId).get(),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const ListTile(title: Text("Loading..."));
                        }

                        if (!userSnapshot.hasData ||
                            userSnapshot.data == null) {
                          return const ListTile(title: Text("User not found"));
                        }

                        final userData =
                            userSnapshot.data!.data() as Map<String, dynamic>;
                        final userName = userData['name'] ?? "";
                        final userEmail = userData['email'] ?? "Unknown";
                        final profileImageUrl =
                            userData['profileImageUrl'] as String?;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: profileImageUrl != null
                                ? NetworkImage(profileImageUrl)
                                : null,
                            child: profileImageUrl == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title:
                              Text(userName.isNotEmpty ? userName : userEmail),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (admins.contains(userId))
                                const Text(
                                  "Admin",
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              if (isAdmin &&
                                  currentUser.uid == widget.adminId &&
                                  !admins.contains(userId) &&
                                  userId != widget.adminId)
                                IconButton(
                                  icon: const Icon(Icons.shield),
                                  onPressed: () async {
                                    final groupSnapshot = await _firestore
                                        .collection('groups')
                                        .doc(widget.groupId)
                                        .get();
                                    final groupData = groupSnapshot.data()
                                        as Map<String, dynamic>;
                                    final admins = List<String>.from(
                                        groupData['admins'] ?? []);

                                    if (!admins.contains(userId)) {
                                      await _firestore
                                          .collection('groups')
                                          .doc(widget.groupId)
                                          .update({
                                        'admins':
                                            FieldValue.arrayUnion([userId]),
                                      });
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                "User promoted to admin.")),
                                      );
                                    }
                                  },
                                ),
                              if (isAdmin &&
                                  userId != widget.adminId &&
                                  userId != currentUser.uid &&
                                  currentUser.uid == widget.adminId &&
                                  !admins.contains(userId))
                                IconButton(
                                  icon: const Icon(Icons.remove_circle),
                                  onPressed: () => _removeUserFromGroup(userId),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: isMember
                          ? null
                          : () async {
                              await _firestore
                                  .collection('groups')
                                  .doc(widget.groupId)
                                  .update({
                                'members':
                                    FieldValue.arrayUnion([currentUser!.uid]),
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("You joined the group.")),
                              );
                              setState(() {});
                            },
                      child: const Text("Join Group"),
                    ),
                    ElevatedButton(
                      onPressed: isMember ? _leaveGroup : null,
                      child: const Text("Leave Group"),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
