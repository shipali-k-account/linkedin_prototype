
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  // Cloudinary account details
  final String cloudName = 'ib5wq18a';
  final String uploadPreset = 'linkedin_profile';

  Future<String> uploadProfileImage(XFile image) async {
    // Cloudinary upload URL
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    // Create upload request
    final request = http.MultipartRequest('POST', url);

    // Add unsigned upload preset
    request.fields['upload_preset'] = uploadPreset;

    // Read image and attach it
    final imageBytes = await image.readAsBytes();

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: image.name,
      ),
    );

    // Send image to Cloudinary
    final response = await request.send();

    // Read server response
    final responseBody = await response.stream.bytesToString();

    final result = jsonDecode(responseBody);

    if (response.statusCode == 200) {
      // Return uploaded image URL
      return result['secure_url'];
    } else {
      throw Exception(
        result['error']?['message'] ?? 'Image upload failed',
      );
    }
  }
}
