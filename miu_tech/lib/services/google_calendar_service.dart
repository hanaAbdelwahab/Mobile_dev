import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart';

class GoogleAuthClient extends BaseClient {
  final Map<String, String> _headers;
  final Client _client = Client();

  GoogleAuthClient(this._headers);

  @override
  Future<StreamedResponse> send(BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GoogleCalendarService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/calendar.events',
    ],
  );

  // 🗑️ Delete event from Google Calendar
  static Future<void> deleteEvent(String eventId) async {
    final account = await _googleSignIn.signIn();
    if (account == null) return;

    final authHeaders = await account.authHeaders;
    final authClient = GoogleAuthClient(authHeaders);
    final calendarApi = gcal.CalendarApi(authClient);

    await calendarApi.events.delete("primary", eventId);
  }

  // ➕ Add event and RETURN the event ID
  static Future<String?> addEvent({
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final account = await _googleSignIn.signIn();
    if (account == null) {
      throw Exception("User cancelled Google Sign-In");
    }

    final authHeaders = await account.authHeaders;
    final authClient = GoogleAuthClient(authHeaders);

    final calendarApi = gcal.CalendarApi(authClient);

    final event = gcal.Event(
      summary: title,
      description: description,
      start: gcal.EventDateTime(
        dateTime: startTime.toUtc(),
      ),
      end: gcal.EventDateTime(
        dateTime: endTime.toUtc(),
      ),
    );

    // 🔑 Insert and return the event ID
    final createdEvent = await calendarApi.events.insert(event, "primary");
    return createdEvent.id; // This is what you need to store!
  }
}