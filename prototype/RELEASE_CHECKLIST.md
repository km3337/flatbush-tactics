# App store release checklist

Things to update before Flatbush Tactics ships on the App Store (iOS) and
Google Play (Android). Store rules change often, so check the current
requirements in App Store Connect and the Play Console when you get there.

## 1. Replace content we don't own (blockers)

Neither store will accept these, and they're also in the public web demo
right now.

- [ ] Enemy sprites: Shin Megami Tensei (© Atlus) and Mega Man Zero 3
      (© Capcom) rips, plus the Metal Snake and Seeker rips whose source isn't
      noted (`assets/enemies/PLACEHOLDER_CREDITS.md`). Only `mutated_rat` is
      original.
- [ ] Effects: Fire Emblem hit spark and Pokémon impact and bite
      (`assets/fx/PLACEHOLDER_CREDITS.md`).
- [ ] Music: "Go Crazy" (Sam Waitin), "Synkro" (Qteku) and "Secret Portraits"
      (New Balance). Either get a written licence for commercial use in a game
      or replace them.
- [ ] Sound effects: the menu select (from a Mega Man Zero SFX collection),
      the "stand clear of the closing doors" announcement and chime (an MTA
      recording), the BATTLE START woosh (source not noted) and the Freesound
      laser zaps (check that clip's licence; CC-BY needs credit, CC0 doesn't).
- [ ] Font: check the Nokia Cellphone FC licence (from fatorcaos.com.br)
      allows commercial use and embedding.
- [ ] NYC subway look: real station names are fine, but avoid MTA logos, the
      route bullets and other official signage.
- [ ] Add a credits screen for anything that needs attribution.

## 2. Accounts and paperwork

- [ ] Apple Developer Program ($99/year). Use a Mac with Xcode for the iOS
      build and upload.
- [ ] Google Play Console ($25 once). New personal accounts must run a closed
      test with a minimum number of testers for a set period before
      production; check the current numbers.
- [ ] Tax and banking forms in both consoles (needed even for a free app if
      you add purchases later).
- [ ] Privacy policy page (for example nullinside.net/privacy). Both stores
      require one.
- [ ] Support URL or contact email.
- [ ] Age rating questionnaires (Apple's own, and IARC on Play). Mention the
      cartoon violence.
- [ ] Data disclosures: the App Privacy labels (Apple) and the Data safety form
      (Play). The app itself collects nothing as long as the GoatCounter
      counter stays in the web build only.
- [ ] Export compliance (Apple): the game uses no custom encryption.

## 3. Project settings (`project.godot`)

- [ ] Version name and build number (`application/config/version`, and the
      per-export version and code). Bump the build number on every upload.
- [ ] Bundle ID / package name, such as `net.nullinside.flatbushtactics`.
      It can't change after the first release.
- [ ] App icon: iOS 1024x1024 with no transparency, Android adaptive icon
      (foreground and background layers), Play listing icon 512x512.
- [ ] Boot splash: replace the Godot logo (the parked load-screen follow-up).
- [ ] Remove the MCP toolkit before exporting: the `MCPRuntimeServer`
      autoload and the `godot_mcp_toolkit` plugin. It's a development tool and
      shouldn't run on players' phones.
- [ ] Turn off debug-only shortcuts, and keep `tests/` excluded from exports.
- [ ] Mobile text: the hints still mention SPACE and keyboard keys. Show
      touch wording on phones.
- [ ] Notches and home bar: check the 360x780 layout against safe areas on
      tall iPhones and Android phones with cutouts.
- [ ] Pause when the app goes to the background (phone call, home button),
      and handle the Android back button.
- [ ] Save data: make sure runs and settings survive the app being closed.
- [ ] iOS audio: in the native app, set the audio session so music respects
      or ignores the silent switch the way you want. The web-only
      `audioSession` script doesn't apply there.

## 4. Builds

- [ ] Install the Android and iOS export templates for Godot 4.6.2. Only the
      web templates are installed now.
- [ ] Android: JDK and Android SDK, set in Editor Settings.
- [ ] Android release keystore. Back it up somewhere safe: losing it means
      you can't sign updates. Turn on Play App Signing.
- [ ] Export an AAB (not an APK) for Play, targeting the API level Play
      currently requires.
- [ ] Android permissions: request none unless needed (the game doesn't need
      internet).
- [ ] iOS: Apple Team ID, signing certificate and provisioning profile;
      export the Xcode project, then archive and upload from Xcode.
- [ ] iOS privacy manifest: check that the export includes one.

## 5. Store listings

- [ ] Name, subtitle (iOS) and short description (Play), full description,
      keywords (iOS).
- [ ] Category: Games › Action (or Arcade).
- [ ] Screenshots at the sizes each store currently requires (portrait suits
      the game).
- [ ] Play feature graphic (1024x500).
- [ ] Optional: a short trailer or app preview video.
- [ ] Price: free, paid, or free with purchases.

## 6. Testing

- [ ] TestFlight build on real iPhones.
- [ ] Play internal test, then the closed test with your testers.
- [ ] Test on a small, older phone and a large new one: frame rate, scaling,
      touch, flicks and charge shots.
- [ ] Interruptions: a call, a notification, locking the phone mid-fight,
      headphones in and out.
- [ ] Airplane mode: the game should run fully offline.

## 7. Launch

- [ ] Update nullinside.net/work/flatbush-tactics with store badges and links.
- [ ] Email the waitlist (export sign-ups from Netlify › Forms › waitlist).
- [ ] Decide whether the browser demo stays up, and update it with the
      replaced art and audio either way.
