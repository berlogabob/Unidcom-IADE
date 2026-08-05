# Unidcom-IADE

## Run

```sh
flutter run -d chrome --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## Run the E2E

```
flutter build web --dart-define=E2E=true
python3 -m http.server 8123 --directory build/web
maestro test .maestro/featured_star.yaml --env-file .maestro/.env
```

The E2E build flag enables web semantics (Maestro selects by visible text/tooltips). `.maestro/.env` holds MAESTRO_EMAIL/MAESTRO_PASSWORD (not committed).
