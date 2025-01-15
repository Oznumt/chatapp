import 'package:cloud_firestore/cloud_firestore.dart';

class GroupMessage {
  final String senderId;
  final String senderEmail;
  final String senderName;
  final String message;
  final Timestamp timestamp;
  final List<String> readBy;
  final String? mediaUrl; 
  final String? fileUrl;

  GroupMessage({
    required this.senderId,
    required this.senderEmail,
    required this.senderName,
    required this.message,
    required this.timestamp,
    required this.readBy,
    this.mediaUrl,
    this.fileUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderEmail': senderEmail,
      'senderName': senderName,
      'message': message,
      'timestamp': timestamp,
      'readBy': readBy,
      'mediaUrl': mediaUrl,
      'fileUrl': fileUrl,
    };
  }

  factory GroupMessage.fromMap(Map<String, dynamic> map) {
    return GroupMessage(
      senderId: map['senderId'] ?? '',
      senderEmail: map['senderEmail'] ?? '',
      senderName: map['senderName'] ?? '',
      message: map['message'] ?? '',
      timestamp: map['timestamp'] ?? Timestamp.now(),
      readBy: List<String>.from(map['readBy'] ?? []),
      mediaUrl: map['mediaUrl'],
      fileUrl: map['fileUrl'],
    );
  }
}
