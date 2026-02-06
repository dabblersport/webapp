# Detect Country Edge Function

This Supabase Edge Function detects the user's country from their IP address using Cloudflare's geolocation headers.

## Deployment

Deploy this function to Supabase:

```bash
supabase functions deploy detect-country
```

## How It Works

1. The function reads the `CF-IPCountry` header automatically added by Cloudflare
2. Maps the ISO country code to a full country name
3. Returns JSON: `{ country: "United Arab Emirates", countryCode: "AE" }`
4. Falls back to `"Global"` if country cannot be detected

## Testing

Test locally:

```bash
supabase functions serve detect-country
```

Test deployed function:

```bash
curl -i https://YOUR_PROJECT_REF.supabase.co/functions/v1/detect-country
```

## Integration

The Flutter app calls this function via `IpCountryDetectionService`:

```dart
final service = IpCountryDetectionService();
final country = await service.detectCountryFromIp();
print(country); // "United Arab Emirates" or "Global"
```

## Priority Chain

Country detection priority in the app:
1. **IP-derived country** (this function) 
2. **Device locale country** (fallback)
3. **"Global"** (safe fallback)

## Notes

- Function requires Cloudflare CDN (enabled by default on Supabase)
- Returns 200 even on errors (with "Global" fallback) for graceful UX
- CORS enabled for all origins
