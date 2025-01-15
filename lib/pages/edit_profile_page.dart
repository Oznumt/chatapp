import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  XFile? _imageFile;

  final ImagePicker _picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .get();
    final userData = userDoc.data();
    if (userData != null) {
      if (userData['name'] != null) {
        _nameController.text = userData['name'];
      }
      if (userData['profileImageUrl'] != null) {
        _profileImageUrl = userData['profileImageUrl'];
      }
    }
    setState(() {});
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _imageFile = pickedFile;
    });
  }

  Future<void> _uploadProfileImage() async {
    if (_imageFile != null) {
      try {
        final userId = _auth.currentUser!.uid;
        final fileName =
            'profile_images/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = _storage.ref().child(fileName);

        await ref.putFile(File(_imageFile!.path));
        final downloadUrl = await ref.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'profileImageUrl': downloadUrl});

        setState(() {
          _profileImageUrl = downloadUrl;
        });
      } catch (e) {
        print('Error uploading profile image: $e');
      }
    }
  }

  Future<void> _removeProfileImage() async {
    try {
      final userId = _auth.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'profileImageUrl': FieldValue.delete()});

      if (_profileImageUrl != null) {
        final ref = _storage.refFromURL(_profileImageUrl!);
        await ref.delete();
      }

      setState(() {
        _profileImageUrl = null;
        _imageFile = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile image removed!')),
      );
    } catch (e) {
      print('Error removing profile image: $e');
    }
  }

  Future<void> _updateUserName(String name) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .update({'name': name});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _imageFile != null
                    ? FileImage(File(_imageFile!.path))
                    : (_profileImageUrl != null
                        ? NetworkImage(_profileImageUrl!)
                        : null) as ImageProvider?,
                child: _imageFile == null && _profileImageUrl == null
                    ? const Icon(Icons.camera_alt, size: 50)
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            if (_profileImageUrl != null || _imageFile != null)
              TextButton(
                onPressed: _removeProfileImage,
                child: const Text(
                  'Remove Profile Image',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final name = _nameController.text.trim();
                await _updateUserName(name.isNotEmpty ? name : '');
                await _uploadProfileImage();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated!')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
