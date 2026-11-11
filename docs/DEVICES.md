# Playing Perihelion on a real iPhone

Three routes, from free and fiddly to paid and easy. Your Apple team ID never goes in the repo: it lives in
`Config/Local.xcconfig`, which git ignores.

## Your own iPhone (free)

A free Apple ID is enough. The catch: the app stops launching after 7 days, and you reinstall it from the Mac.

1. In Xcode, open **Settings → Accounts** and add your Apple ID. Xcode creates a free "Personal Team".
2. Run `just teams` to see your team ID, then create the local signing file:

   ```bash
   cp Config/Local.xcconfig.example Config/Local.xcconfig
   ```

   and put your team ID in it.
3. Plug the iPhone in, unlock it and tap **Trust**. Turn on **Settings → Privacy & Security → Developer Mode** and let
   the phone restart.
4. Find the phone's name with `just phones`, then build, install and launch the Release build:

   ```bash
   just device "Your iPhone"
   ```

5. The first launch is blocked until you trust yourself, which is a sentence I never expected to write: **Settings →
   General → VPN & Device Management**, pick your Apple ID and tap **Trust**.

Friends can do the same with their phone plugged into your Mac, with the same 7-day limit. Fine for one friend on
your sofa, not for a group chat.

## Friends' iPhones: TestFlight (Apple Developer Program)

This needs the paid [Apple Developer Program](https://developer.apple.com/programs/) (US$99 a year at the time of
writing, or the local equivalent; enrolment includes an identity check that can take a day or two). Ad hoc builds
tied to device IDs need the same membership, so TestFlight is the easier way to spend it.

1. Once enrolled, run `just teams` again and put the **paid** team ID in `Config/Local.xcconfig`.
2. In [App Store Connect](https://appstoreconnect.apple.com), go to **Apps → + → New App**: platform iOS, a name
   (check early whether "Perihelion" is free on the store), bundle ID `io.github.glukicov.perihelion`, and any SKU.
   If the bundle ID is not in the list yet, the first archive registers it through automatic signing.
3. Upload a build:

   ```bash
   just testflight
   ```

   It archives a Release build with a fresh, date-based build number and uploads it with the account you signed in
   to Xcode with.
4. In App Store Connect, open **TestFlight**. Processing takes 10 to 30 minutes. Export compliance is already answered
   (`ITSAppUsesNonExemptEncryption` is `false`), so the build goes straight to "Ready to test" for internal testers.
5. **You first:** add yourself as an internal tester and install Apple's TestFlight app on your phone.
6. **Friends:** create an external testing group, add the build, and fill in the test information (a one-line
   description and a feedback email). The first external build goes through Beta App Review, usually within a day.
   Then turn on the **public link** and share it. Friends install TestFlight, tap the link, and play.

Builds expire after 90 days. Every `just testflight` gets a new build number, so uploading again is the whole update
process.

## The App Store (later)

Same membership, plus a full review. Before submitting:

- sound and the real fonts in the app, and a few TestFlight players
- store screenshots for the required iPhone sizes, a description and keywords, an age rating
- the privacy label: "Data Not Collected" (the game only keeps your best score and furthest star on the phone, which
  the bundled `PrivacyInfo.xcprivacy` declares)
- a support URL (the GitHub repo will do) and a privacy policy URL

## What is already set up

| Piece | Where |
|---|---|
| Automatic signing, team ID read from an ignored local file | `Config/Base.xcconfig`, `Config/Local.xcconfig.example` |
| Privacy manifest for the `UserDefaults` used by saved records | `App/PrivacyInfo.xcprivacy` |
| Export compliance answered | `ITSAppUsesNonExemptEncryption = false` in `project.yml` |
| App icon and launch colour | `App/Assets.xcassets` |
| Upload settings for TestFlight | `Config/ExportOptions.plist` |
| Recipes | `just teams`, `just phones`, `just device`, `just archive`, `just testflight` |
