import 'dart:io';
import 'package:chatapp/models/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class ChatService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _firestore.collection("users").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return doc.data();
      }).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> getUsersStreamExceptBlocked() {
    final currentUser = _auth.currentUser;

    return _firestore
        .collection("users")
        .doc(currentUser!.uid)
        .collection("blockedUsers")
        .snapshots()
        .asyncMap((snapshot) async {
      final blockedUserIds = snapshot.docs.map((doc) => doc.id).toList();

      final usersSnapshot = await _firestore.collection("users").get();

      return usersSnapshot.docs
          .where((doc) =>
              doc.data()['email'] != currentUser.email &&
              !blockedUserIds.contains(doc.id))
          .map((doc) => doc.data())
          .toList();
    });
  }

  Future<String?> uploadFile(File file, String folderName) async {
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

  Future<void> sendMessage(String receiverId, String message, {String? mediaUrl}) async {
    final String currentUserId = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();

    Message newMessage = Message(
      senderId: currentUserId,
      senderEmail: currentUserEmail,
      receiverId: receiverId,
      message: message,
      timestamp: timestamp,
      status: 'sent',
      mediaUrl: mediaUrl,
    );

    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatRoomID = ids.join("_");

    await _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .add(newMessage.toMap());
  }

  Future<void> updateMessageStatus(
      String chatRoomID, String messageId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection("chat_rooms")
          .doc(chatRoomID)
          .collection("messages")
          .doc(messageId)
          .update({'status': status});
      print("Message status updated to $status");
    } catch (e) {
      print("Error updating message status: $e");
    }
  }

  Future<void> markMessagesAsRead(String chatRoomID) async {
    final currentUserId = _auth.currentUser!.uid;

    try {
      final messagesSnapshot = await _firestore
          .collection("chat_rooms")
          .doc(chatRoomID)
          .collection("messages")
          .where('receiverId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'sent')
          .get();

      for (var doc in messagesSnapshot.docs) {
        await doc.reference.update({'status': 'read'});
      }
    } catch (e) {
      print("Error marking messages as read: $e");
    }
  }

  Future<void> deleteMessage(String chatRoomID, String messageId) async {
    try {
      await _firestore
          .collection("chat_rooms")
          .doc(chatRoomID)
          .collection("messages")
          .doc(messageId)
          .delete();
      print("Message deleted: $messageId");
    } catch (e) {
      print("Error deleting message: $e");
    }
  }

  Stream<QuerySnapshot> getMessages(String userId, String otherUserId) {
    List<String> ids = [userId, otherUserId];
    ids.sort();
    String chatRoomID = ids.join("_");

    return _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .orderBy("timestamp", descending: false)
        .snapshots();
  }

  Future<void> reportUser(String messageId, String userId) async {
    final currentUser = _auth.currentUser;
    final report = {
      'reportedBy': currentUser!.uid,
      'messageId': messageId,
      'messageOwnerId': userId,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('reports').add(report);
  }

  Future<void> blockUser(String userId) async {
    final currentUser = _auth.currentUser;
    await _firestore
        .collection("users")
        .doc(currentUser!.uid)
        .collection("blockedUsers")
        .doc(userId)
        .set({});

    notifyListeners();
  }

  Future<void> unblockUser(String blockedUserId) async {
    final currentUser = _auth.currentUser;
    await _firestore
        .collection("users")
        .doc(currentUser!.uid)
        .collection("blockedUsers")
        .doc(blockedUserId)
        .delete();
  }

  Stream<List<Map<String, dynamic>>> getBlockedUsersStream(String userId) {
    return _firestore
        .collection("users")
        .doc(userId)
        .collection("blockedUsers")
        .snapshots()
        .asyncMap((snapshot) async {
      final blockedUserIds = snapshot.docs.map((doc) => doc.id).toList();

      final userDocs = await Future.wait(blockedUserIds
          .map((id) => _firestore.collection("users").doc(id).get()));

      return userDocs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    });
  }
}
