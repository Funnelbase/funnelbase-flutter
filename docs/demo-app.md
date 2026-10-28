# The trading demo

The demo is a small trading app that uses the SDK the way a customer's app would. It exists three
times, screen for screen and with the same taxonomy: `demo-android` in
[funnelbase-android](https://github.com/Funnelbase/funnelbase-android), `demo-ios` in
[funnelbase-ios](https://github.com/Funnelbase/funnelbase-ios), and `demo-flutter` here. The three
read as one product in the dashboard, and a change to what one sends is a change to all three.
How to configure and run the Flutter one is in [sdk-flutter.md](sdk-flutter.md#the-demo-app).

## What it sends

**`$screen_view`, and one custom event.** Screen views carry `screen_name` and nothing else —
they say where the user is. What the user is looking at is a custom event: the instrument page
sends `instrument_viewed` with the ticker in `symbol`. `lib/analytics/events.dart` is the list of
custom events, as `lib/analytics/screens.dart` is the list of screens.

The reserved events — `$session_start`, `$first_open`, `$identify`, the screen views and the push
events — need no declaring: every app's catalog has them from the start. The custom event does.
Before running the demo against a fresh app, declare it under Data → Event catalog, or the server
rejects every one with `unknown_event`:

| Event | Properties | Fires |
|---|---|---|
| `instrument_viewed` | `symbol` — string, required | when an instrument's detail page is shown |

Declaring `symbol` is also what makes it a "Break down by" choice on the Events page, so "which
instruments do people look at" is one selection away.

| Screen | `screen_name` |
|---|---|
| Welcome | `welcome` |
| Sign in | `sign_in` |
| Sign-up intro, pages 1–3 | `signup_intro_1`, `signup_intro_2`, `signup_intro_3` |
| Sign-up username step | `signup_username` |
| The four tabs | `dashboard`, `markets`, `orders`, `news` |
| Instrument detail | `instrument_detail` |
| Notifications, from the dashboard's bell | `push_settings` |
| Notification topics, from the Notifications screen | `notification_settings` |

The names are deliberately separate from the navigation routes. They look almost identical and
they are not the same thing: routes are addresses the navigator resolves, screen names are a
dashboard dimension. Sharing one string means a routing refactor silently renames a chart's series.

The Orders chips (Pending / Cancelled / Filled) filter within a screen and emit nothing. Only
screen and tab changes are screen changes.

## Identity

There is no auth backend — any username and any password sign you in, as intended. The username
is not throwaway though: it is hashed into the `user_id` every later event carries.

```
"ada"  →  u_1f3a...   (SHA-256 of the trimmed, lowercased name, first 64 bits)
```

Same name, same id, every launch, every device and every one of the three demos. A random id would
make each sign-in a new person and every retention number meaningless. The sign-up screen shows the
derived id live as you type.

The demo follows the [event contract](event-contract.md), and `AppState` is the one place it
touches identity:

- Sign-in → `identify`, with `username` and `plan`. There is no billing either: the sign-in
  screen's **Pro plan** switch says which plan the account is on, and a pro sign-in also sends
  `plan_renews_on`, a calendar day 30 days ahead ([event-contract.md](event-contract.md#dates)).
  The day is kept with the username, so a relaunch sends the same one, moved on by 30 days at a
  time once it has passed. A sign-up is free.
- Sign-up → the same `identify`, and nothing before it. The `$identify` carries the device's
  anonymous id and the new user id together, and that one event is the link: the welcome and intro
  screens viewed before the account existed become the account's.
- Sign-in as a **different** account than the last one → the SDK resets first, on its own: a
  fresh anonymous id and a new session, so the second account's visit is never stitched to the
  first.
- Sign-out → `reset`, which uploads the queue before clearing identity, restarts the anonymous id,
  and starts a new session. The welcome screen afterwards is an anonymous stretch of its own.
- Every launch while signed in → `identify` again, as the launch's first event, so the session
  start and the install's `$first_open` carry the account.

To use the traits in segments, declare `username`, `plan` and `plan_renews_on` (as `date`) as
optional properties of the built-in `$identify` in the catalog.

## Push

The dashboard's bell opens a Notifications screen, which makes the parts of push that usually need
a provider visible on an emulator:

- **The permission.** From Android 13 a notification needs it. The SDK never asks — it has no
  screen to ask from — so the app prompts and the SDK reads the answer, re-registering the token
  because its `status` *is* the permission.
- **The token.** With Firebase configured the SDK registers one at startup. Without it, the screen
  registers a token of your own as kind `opaque`, which is enough for the dashboard to target this
  install through a custom HTTP integration.
- **Three simulate buttons.** Each hands the SDK the same `data` map the server sends, so
  everything after the transport is real: the parse, the notification, its image and buttons, the
  `$push_received` event, and the tap that reports `$push_opened` with the button's `action_id`.
  The image is fetched from the host's port 9099; without anything serving it the notification still
  shows, without its picture.
- **Topics.** A "Choose topics" card opens the notification settings screen: the app's topics as
  `Analytics.topics.fetch()` reads them — none is hard-coded, so a topic added in the dashboard
  appears on the next open — with a switch each. When notifications are off it says so and opens
  the system notification settings.

A tapped push carrying a deep link is routed: `trade://instrument/AAPL` and the four tab links are
understood, and anything else leaves the app where it is, because a campaign is written long after
a build ships.

## The data

Fifty S&P 500 constituents, priced randomly **at every launch**. Prices are drawn from a per-ticker
band so the list stays plausible (Berkshire never trades below Ford), and the day's move is bounded
to ±5%. Everything is generated once and shared, so the portfolio, the orders and the news feed
agree on every price; derived figures are computed, never stored, so nothing on screen can
contradict the arithmetic a reader does.

Money is formatted `en-US`/USD throughout, fixed rather than device-locale: the instruments are
dollar-denominated, and formatting them with the phone's locale would render a dollar amount with
European grouping. Colour never carries meaning alone — every green/red price move is paired with
a ▲/▼ glyph.
