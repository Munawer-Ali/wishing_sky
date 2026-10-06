# wishing_sky

https://github.com/user-attachments/assets/9559c8c2-b1f2-4be5-b70e-bd568ecfee3e

A night sky of stars that really exploded. When a telescope catches a new
one, it goes **boom!** on your screen and you get to make a wish on it.

The stars are live. Every exploding star comes from the ZTF telescope at
Palomar Observatory, usually seen just hours before it shows up here.

## Try it

- In the browser: https://wishing-sky.munawera808.workers.dev
- Android app: https://wishing-sky.munawera808.workers.dev/wishing-sky.apk

## Running it

```sh
flutter pub get
flutter run
flutter test
```

Built against Flutter 3.44, Dart SDK ^3.12. Moving the phone to look around
needs a real device; on a laptop or simulator you drag instead.

## What it does

| | |
|---|---|
| drag, pinch, or move the phone | look around the sky |
| yellow dot with **boom!** | a star that exploded in the last 24 hours |
| tap a star | see when it was seen, how far it is, and make a wish |
| tap the star's name | give it your own name, it stays above the star |
| mic button | say your wish instead of typing it |
| today's booms | every star from today, newest on top |
| my wishes | all your wishes, saved on the phone |

## How it works

| File | |
|---|---|
| `lib/sky_data.dart` | telescope feed, bright star catalog, time and distance helpers |
| `lib/sky_view.dart` | the sky: projection, gestures, phone tilt, explosions, paper plane |
| `lib/home_screen.dart` | refresh loop, banner, today's list |
| `lib/star_sheet.dart` | the diary page: star details, naming, voice wish |
| `lib/wishes.dart` | saved wishes and names, the wishes page |
| `lib/notifications.dart` | Firebase push |
| `lib/look.dart` | colors, paper notes, ruled paper |
| `notifier/` | Cloudflare Worker that sends the push notifications |

**Exploding stars** come from the [ALeRCE](https://alerce.online) API, which
classifies alerts from the ZTF survey. The app asks for supernova candidates
first seen in the last 7 days and checks again every 5 minutes. A star you
have already seen never explodes twice.

**The sky** is a real catalog of about 2,000 bright stars (Yale Bright Star
Catalog), drawn with a stereographic projection, the same kind planetariums
use. Each exploding star sits at its real position.

**Each boom star follows a real supernova light curve.** It starts small and
blue-white, gets brighter for about 18 days, then fades through yellow,
orange and red over the following months. The look depends on the star's real
age from the telescope data, so tomorrow it will look a little different.

**Distance** is a rough estimate from how bright the explosion looks, so the
app always says "about". That is also the number behind "your wish will get
there in about 2.4 billion years".

## Firebase keys

The Firebase API keys in `android/app/google-services.json`,
`ios/Runner/GoogleService-Info.plist` and `lib/firebase_options.dart` are left
empty. Connect your own Firebase project before running:

```sh
flutterfire configure
```

## Notifications

`notifier/` is a Cloudflare Worker on a 10 minute timer. It asks the telescope
for new stars, remembers the ones it has seen in Workers KV, and sends a
Firebase Cloud Messaging push to the `new-stars` topic. The app subscribes to
that topic on start.

To keep it calm there are at most 3 notifications a day, at least 4 hours
apart. Stars that show up in between are counted and sent together, like
"4 stars exploded".

To run your own:

```sh
cd notifier
npx wrangler kv namespace create SKY --config wrangler.toml
npx wrangler secret put FIREBASE_SERVICE_ACCOUNT --config wrangler.toml
npx wrangler secret put TEST_KEY --config wrangler.toml
npx wrangler deploy --config wrangler.toml
```

Put the KV id in `wrangler.toml`. `FIREBASE_SERVICE_ACCOUNT` is the service
account JSON from your Firebase project settings. Opening
`/test?key=TEST_KEY` on the worker sends a test notification.

Android only for now; iOS push needs an Apple developer account.

## Credits

- Exploding star data: [ALeRCE](https://alerce.online) and the
  [Zwicky Transient Facility](https://www.ztf.caltech.edu)
- Bright stars: Yale Bright Star Catalog
- Font: [Patrick Hand](https://fonts.google.com/specimen/Patrick+Hand) by
  Patrick Wagesreiter, SIL Open Font License
