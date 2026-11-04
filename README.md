# Tolt for Swift

Let users enter a partner's code in your iOS or macOS app and credit that partner with the user's purchases. Purchases reach Tolt through your RevenueCat integration, matched on the same app user id.

## Install

Add the package in Xcode (File > Add Package Dependencies) with the URL of this repository, or in `Package.swift`:

```swift
.package(url: "https://github.com/toltapp/tolt-swift", from: "0.1.0")
```

## Use

Configure once at launch with your organization's public id (the same `data-tolt` value tolt.js uses):

```swift
import Tolt

Tolt.configure(publicId: "YOUR_PUBLIC_ID")
```

When the user enters a code, claim it for their app user id. Use the id you pass to RevenueCat as `appUserID`:

```swift
do {
    let result = try await Tolt.claim(code: code, appUserId: appUserId)
    // result.status is .claimed, or .alreadyClaimed if this user claimed a code before
} catch ToltError.codeNotFound {
    // show "That code doesn't exist"
} catch ToltError.codeConflict(let message) {
    // the code is ambiguous, or the program's claim window has closed
}
```

Also store the code on the RevenueCat customer. Tolt uses it if a purchase arrives before the claim does:

```swift
Purchases.shared.attribution.setAttributes(Tolt.revenueCatAttributes(code: code))
```

The SDK records when the app was first opened and sends it with each claim, so programs with a claim window can enforce it.

## Partner links

Partners in an app program can also share a link instead of a code. The link records a click and sends the user to your deep link template (set in the program's settings), with the partner's code and click id filled in through `{code}` and `{click_id}`.

If the link opens your app through a universal link or a custom scheme, pass the URL to Tolt. Use a template like `myapp://claim?tolt_code={code}&tolt_click={click_id}`:

```swift
.onOpenURL { url in
    Task { try? await Tolt.claim(url: url, appUserId: appUserId) }
}
```

`claim(url:)` returns `nil` when the URL has no `tolt_click` or `tolt_code`, so you can call it for every link your app opens.

If you use a deep linking provider such as AppsFlyer OneLink, put `{code}` and `{click_id}` in its parameters, for example `deep_link_value={code}&deep_link_sub1={click_id}`. Then claim from its deep link callback, which also covers fresh installs:

```swift
try await Tolt.claim(clickId: clickId, appUserId: appUserId)
```

## Errors

| Error | Meaning |
| --- | --- |
| `notConfigured` | `configure(publicId:)` was not called |
| `invalidInput` | The code, click id or app user id was blank |
| `codeNotFound` | No active partner has this code, or the click doesn't exist |
| `codeConflict` | The code belongs to more than one partner, or the claim window closed |
| `rateLimited` | Too many claims from this device's network; retry later |
| `server` | Anything else, with the HTTP status and message |
