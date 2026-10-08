# fl_place_autocomplete_web

The web implementation of
[`fl_place_autocomplete`](https://pub.dev/packages/fl_place_autocomplete),
built on the Places library of the
[Maps JavaScript API](https://developers.google.com/maps/documentation/javascript/place-autocomplete-data)
(`AutocompleteSuggestion`, `AutocompleteSessionToken`, `Place.fetchFields`).

This package is [endorsed](https://flutter.dev/to/endorsed-federated-plugin):
depend on `fl_place_autocomplete` and it is included automatically.

## Setup

- Use a browser key with **Maps JavaScript API** and **Places API (New)**
  enabled, restricted to your HTTP referrers.
- Load the Maps JavaScript API with Google's
  [dynamic library import bootstrap loader](https://developers.google.com/maps/documentation/javascript/load-maps-js-api#dynamic-library-import)
  in `web/index.html`, inside `<head>`:

```html
<script>
  (g=>{var h,a,k,p="The Google Maps JavaScript API",c="google",l="importLibrary",q="__ib__",m=document,b=window;b=b[c]||(b[c]={});var d=b.maps||(b.maps={}),r=new Set,e=new URLSearchParams,u=()=>h||(h=new Promise(async(f,n)=>{await (a=m.createElement("script"));e.set("libraries",[...r]+"");for(k in g)e.set(k.replace(/[A-Z]/g,t=>"_"+t[0].toLowerCase()),g[k]);e.set("callback",c+".maps."+q);a.src=`https://maps.${c}apis.com/maps/api/js?`+e;d[q]=f;a.onerror=()=>h=n(Error(p+" could not load."));a.nonce=m.querySelector("script[nonce]")?.nonce||"";m.head.append(a)}));d[l]?console.warn(p+" only loads once. Ignoring:",g):d[l]=(f,...n)=>r.add(f)&&u().then(()=>d[l](f,...n))})({
    key: "YOUR_API_KEY",
    v: "weekly",
  });
</script>
```

The plugin calls `google.maps.importLibrary('places')` itself. If the loader is
missing, calls fail with `PlaceAutocompleteErrorCode.invalidApiKey`.

## Platform notes

- **Sessions:** the Maps JavaScript API only carries a session token into
  place details through `placePrediction.toPlace()`. This package therefore
  keeps, per session, the token and the original prediction objects keyed by
  place id. `fetchPlace` with a session uses the cached prediction; if the
  place id is not cached for that session it falls back to `new Place({id})`
  without a token, logs a warning, and that request is **billed outside the
  session**. Cached predictions are dropped when the session ends or is
  disposed.
- **Language/region:** honored for predictions. For place details they only
  apply outside a session (or on the fallback path), because `toPlace()` takes
  neither.
- **Photos:** `fetchPhoto` returns a URI (`PhotoData.uri`) for photos of places
  fetched in the current page.
- Place details are read from `Place.toJSON()`.

## Development

```sh
flutter test --platform chrome
```

The tests stub `google.maps`; they do not call the live API.
