import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIService {
  static String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  static Future<Map<String, dynamic>> analyzeApplication({
    required List<String> userSkills,
    required List<String> userExperiences,
    required List<String> userLicenses,
    required String introduction,
    required List<String> projectSkills,
    required String projectDescription,
    // New Profile Attributes
    String? userRole,
    String? userDepartment,
    String? userAcademicYear,
    String? userBio,
    String? userLocation,
  }) async {
    try {
      if (_apiKey.isEmpty || _apiKey == 'YOUR_OPENAI_API_KEY_HERE') {
        debugPrint('⚠️ OpenAI API Key is missing');
        return {'score': 0.0, 'reason': 'API Key missing'};
      }

      final prompt =
          '''
      You are an AI recruiter. Analyze the following job application against the project requirements.
      
      Project Description: "$projectDescription"
      Required Skills: ${projectSkills.join(', ')}
      
      Applicant Profile:
      - Role: ${userRole ?? 'N/A'}
      - Department: ${userDepartment ?? 'N/A'}
      - Academic Year: ${userAcademicYear ?? 'N/A'}
      - Location: ${userLocation ?? 'N/A'}
      - Bio: "${userBio ?? 'N/A'}"
      
      Applicant Skills: ${userSkills.join(', ')}
      Applicant Experience: ${userExperiences.join('; ')}
      Applicant Licenses/Certifications: ${userLicenses.join('; ')}
      Applicant Introduction: "$introduction"
      
      Task:
      1. Compare the applicant's profile, skills (names, proficiency, endorsements), experience, licenses, and introduction to the project requirements.
      2. Provide a match score from 0.0 to 5.0 using this rubric:
         - 5.0 (Perfect): Has ALL required skills at High/Expert level + relevant experience/endorsements/licenses.
         - 4.0-4.9 (Strong): Has all/most skills but lower proficiency, or missing only minor skills/experience.
         - 3.0-3.9 (Moderate): Missing one key skill or low proficiency in key areas, or limited experience.
         - < 3.0 (Weak): Missing multiple key skills or relevant experience.
      3. Provide a concise 1-sentence reason for the score.
      
      Return ONLY a JSON object in this format:
      {
        "score": 4.5,
        "reason": "Strong skill match but lacks mentioned experience in..."
      }
      ''';

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a helpful assistant that outputs only JSON.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];

        // Clean up code blocks if present
        final cleanContent = content
            .toString()
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        try {
          final result = jsonDecode(cleanContent);
          return {
            'score': (result['score'] as num).toDouble(),
            'reason': result['reason'].toString(),
          };
        } catch (e) {
          debugPrint('❌ Error parsing AI response: $e');
          return {'score': 0.0, 'reason': 'Error parsing AI response'};
        }
      } else {
        debugPrint(
          '❌ OpenAI API Error: ${response.statusCode} - ${response.body}',
        );
        return {'score': 0.0, 'reason': 'AI Analysis Failed'};
      }
    } catch (e) {
      debugPrint('❌ AI Service Error: $e');
      return {'score': 0.0, 'reason': 'Service Error'};
    }
  }
}
