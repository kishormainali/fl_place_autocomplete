# Sessions and billing

Google bills Autocomplete (New) differently depending on whether requests are
grouped into a **session** with a session token. This plugin manages the tokens
for you; this page explains what it does, and what you are responsible for.

> Google's pricing and session rules change. Treat the summary below as a
> pointer and always check the linked Google pages before relying on a number.

## Google's rules (checked 2026-10-08)

Sources (all showed "Last updated 2026-10-07 UTC" when checked):

- [Session tokens (Places API, New)](https://developers.google.com/maps/documentation/places/web-service/place-session-tokens)
- [Session tokens (Places SDK for Android)](https://developers.google.com/maps/documentation/places/android-sdk/place-session-tokens)
- [Session pricing for Autocomplete (New)](https://developers.google.com/maps/documentation/places/web-service/session-pricing)
- [Place Autocomplete Data API (Maps JavaScript API)](https://developers.google.com/maps/documentation/javascript/place-autocomplete-data)

What those pages say:

- A session **begins** with the first Autocomplete (New) request and
  **concludes** with a Place Details (New) request (or an Address Validation
  request) that carries the same token. A session can contain many
  autocomplete requests.
- Once a session has concluded the token is **no longer valid**; a fresh token
  is required for every new session. Reusing a token, or omitting it, makes
  each request billable on its own.
- A session that is **abandoned** (never concluded by Place Details) reverts to
  per-request pricing: its autocomplete requests are billed under the
  "Autocomplete Requests" SKU.
- For a session concluded by Place Details, autocomplete requests are billed
  under "Autocomplete Session Usage" (no charge), except when the session ends
  with a **Place Details Essentials (IDs Only)** request, where autocomplete
  requests revert to per-request pricing. Session-pricing also describes a cap
  for sessions ending in Place Details Essentials: the first 12 autocomplete
  requests are charged individually and requests 13+ are free. Read the
  session-pricing page for the exact current rules.
- **Token expiry:** none of the pages above states a numeric expiry or timeout
  for a session token. The only time-related statement found is on the Maps
  JavaScript API page, which says that if the user does not make a selection
  "within a few minutes" of the start of the session, only the search query is
  charged. The plugin therefore does **not** hard-code any expiry: it never
  expires sessions by time, it ends them on a successful `fetchPlace` or when
  they are abandoned (see below). If you keep a session open for a long time,
  Google may treat it as abandoned and bill per request.

## Lifecycle in this plugin

Sessions are owned by Dart. `newSession()` returns an opaque `PlaceSession`;
each platform maps its id to a real token lazily, on the first request.

```dart
final places = FlPlaceAutocomplete.instance;
final session = places.newSession();

final predictions = await places.findPredictions('eiff', session: session);
final more = await places.findPredictions('eiffel', session: session); // same token

final place = await places.fetchPlace(
  predictions.first.placeId,
  session: session,                         // concludes the session
  fields: {PlaceField.displayName, PlaceField.location},
);

session.isEnded; // true; any further use throws StateError
```

| Event | What happens |
|-------|--------------|
| `findPredictions(..., session: s)` | Native side creates a token for `s` on first use and reuses it for every later request with `s`. |
| `fetchPlace(..., session: s)` succeeds | The token is sent with the details request, then dropped natively; `s` is ended. Reusing `s` throws `StateError`. |
| `fetchPlace(..., session: s)` fails | `s` stays **active** and keeps its token, so a retry still concludes the same session. |
| `cancelSession(s)` | `s` is ended and its native token disposed. Google bills the session as abandoned. |
| No `session:` argument | No token is sent; every request is billed on its own. |

### `PlaceAutocompleteField` / `PlaceAutocompleteController`

The widget manages sessions for you:

- The first query after a user edit creates a session; later queries reuse it.
- Selecting a prediction (with the default `fetchDetailsOnSelect: true`) calls
  `fetchPlace` with that session, which concludes it. The next edit starts a
  new session.
- Losing focus, `clear()`, `setText()` or `setPlace()` without a selection
  cancels (disposes) the session: billed as abandoned.
- Losing focus while a selection's `fetchPlace` is in flight defers that: a
  successful fetch concludes the session as usual; a failed one is reported
  via `onError` and the session is then cancelled (no error list is shown
  under the unfocused field).
- Disposing the field (or swapping its controller) calls
  `controller.detach()` on an external controller: the pending query is
  dropped and the session cancelled, so no request is made after the field is
  gone.
- `initialValue`, `initialPlace`, focusing the field and programmatic text
  changes never create a session or call the API.

### `fetchDetailsOnSelect: false`

If you want to fetch details yourself (different fields, later, or not at
all), take the session **synchronously inside `onPredictionSelected`**:

```dart
final controller = PlaceAutocompleteController();

PlaceAutocompleteField(
  controller: controller,
  fetchDetailsOnSelect: false,
  onPredictionSelected: (prediction) {
    final session = controller.takeSession(); // now yours
    FlPlaceAutocomplete.instance.fetchPlace(
      prediction.placeId,
      session: session,
      fields: {PlaceField.location},
    );
  },
);
```

After `takeSession()` the controller no longer owns the session, so you must
end it, with `fetchPlace` or `cancelSession`. If you do not take it, the
controller disposes it as soon as the field loses focus or is cleared, and a
later `fetchPlace` with it would throw `StateError`.

## Platform details

- **Android:** `AutocompleteSessionToken.newInstance()` per session id; the same
  token goes to `FetchPlaceRequest`; the entry is removed after a successful
  fetch or `disposeSession`.
- **iOS:** `GMSAutocompleteSessionToken` per session id; same pattern.
- **Web:** the Maps JavaScript API only carries the session token into place
  details through `placePrediction.toPlace()`. The web implementation
  therefore caches, per session, the token **and the original prediction
  objects** keyed by place id. `fetchPlace` with a session:
  - finds the cached prediction and calls `toPlace()` then `fetchFields()`:
    billed as the end of the session;
  - if the place id is **not** in that session's cache (for example, it came
    from a different session or from storage), falls back to a bare
    `new Place({id})` with no token, logs a warning
    (`fl_place_autocomplete`, level WARNING) and is **billed outside the
    session**.
  - `toPlace()` takes no language or region, so `languageCode` / `regionCode`
    passed to an in-session `fetchPlace` are ignored on web.

  Cached predictions are dropped when the session concludes or is disposed;
  a prediction response that arrives after that is not cached, so it cannot
  revive the ended session.
  `fetchFields` receives the JS `Place` property names, which match
  `PlaceField.apiName` except `websiteURI` and `googleMapsURI`.

## Field billing tiers

The Place Details SKU charged for `fetchPlace` depends on the **most expensive
field** you request (Essentials IDs Only, Essentials, Pro, Enterprise,
Enterprise + Atmosphere). For example, `id`/`photos` are IDs Only, `location`
and `formattedAddress` are Essentials, `displayName` is Pro, `rating` and
`websiteUri` are Enterprise, `reviews` is Enterprise + Atmosphere (per Google's
table on 2026-10-08). Request only the `PlaceField`s you need; see Google's
[Place Details (New) data fields](https://developers.google.com/maps/documentation/places/web-service/data-fields)
and [pricing](https://developers.google.com/maps/billing-and-pricing/pricing)
for the current mapping.

The widget's default `fields` are `location`, `displayName` and
`formattedAddress`; `displayName` puts that at the Pro tier.
