# omni_chat

A realtime audio/video calling with chat.

1v1 text chat and peer-to-peer WebRTC video calls, built with Flutter and Bloc on Firebase
Authentication and Realtime Database. Runs on web, Android and iOS.

## Setup

The Firebase config files are not in this repo. To run the app, connect it to your own Firebase
project.

### 1. Create a Firebase project

In the [Firebase console](https://console.firebase.google.com/):

1. Create a project. The free Spark plan is enough.
2. In **Authentication → Sign-in method**, enable **Email/Password**.
3. In **Realtime Database**, create a database instance.

Create the database **before** you run `flutterfire configure`, so its URL ends up in the generated
config.

### 2. Generate the config files

Install the [Firebase CLI](https://firebase.google.com/docs/cli) and the FlutterFire CLI, then run
from the project root:

```sh
dart pub global activate flutterfire_cli
firebase login
flutterfire configure --project=<your-project-id> --platforms=android,ios,web
```

This creates the files listed under "Firebase config" in `.gitignore`:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `firebase.json`

Check that each of them contains your database URL
(`https://<your-project-id>-default-rtdb.firebaseio.com`). If one is missing it, the app crashes
at startup with a `duplicate-app` error. Add it by hand:

| File | Key |
|---|---|
| `lib/firebase_options.dart` | `databaseURL:` in each platform's `FirebaseOptions` |
| `android/app/google-services.json` | `"firebase_url"` under `project_info` |
| `ios/Runner/GoogleService-Info.plist` | `<key>DATABASE_URL</key>` |

### 3. Deploy the database rules

Add the rules file to the generated `firebase.json`:

```json
"database": {
  "rules": "database.rules.json"
}
```

Then deploy:

```sh
firebase deploy --only database --project=<your-project-id>
```

The rules keep users from reading other users' messages, call data and email index. Deploy them
before you put any real data in the database.

### 4. Run

```sh
flutter pub get
flutter run -d chrome
```

Calls use public STUN servers only, so calls between some networks won't connect. To add a TURN
server:

```sh
flutter run --dart-define=TURN_URL=turn:host:3478 --dart-define=TURN_USER=u --dart-define=TURN_PASS=p
```

On iOS, calls need a physical device. The simulator has no camera.

## Tests

```sh
flutter test
```
