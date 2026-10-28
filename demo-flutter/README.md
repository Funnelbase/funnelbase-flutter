# demo-flutter

The trading demo in Flutter: the native demos screen for screen, over `funnelbase_flutter`
(`../packages`). How to configure and run it is in
[docs/sdk-flutter.md](../docs/sdk-flutter.md#the-demo-app); the taxonomy it sends is
[docs/demo-app.md](../docs/demo-app.md)'s.

```bash
flutter pub get                      # at the repository root, once
cp config.example.json config.json   # fill in the ingest keys
flutter run --dart-define-from-file=config.json
flutter test
```
