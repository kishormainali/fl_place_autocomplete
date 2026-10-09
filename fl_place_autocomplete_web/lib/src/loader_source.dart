import 'dart:convert';

/// `id` of the `<script>` element the plugin injects to load Maps JS.
const mapsLoaderScriptId = 'fl-place-autocomplete-maps-loader';

/// Google's documented inline "dynamic library import" bootstrap for the Maps
/// JavaScript API, with [apiKey] and [version] embedded.
///
/// Running it defines `google.maps.importLibrary`; the API script itself is
/// only fetched on the first `importLibrary` call. Both values are embedded
/// as JSON-encoded string literals, so no key content can break out of the
/// string (quotes, backslashes, `</script>`, line separators).
///
/// See https://developers.google.com/maps/documentation/javascript/load-maps-js-api
String buildLoaderSource(String apiKey, {String version = 'weekly'}) =>
    '(g=>{var h,a,k,p="The Google Maps JavaScript API",c="google",'
    'l="importLibrary",q="__ib__",m=document,b=window;b=b[c]||(b[c]={});'
    'var d=b.maps||(b.maps={}),r=new Set,e=new URLSearchParams,'
    'u=()=>h||(h=new Promise(async(f,n)=>{await (a=m.createElement("script"));'
    'e.set("libraries",[...r]+"");for(k in g)e.set(k.replace(/[A-Z]/g,'
    't=>"_"+t[0].toLowerCase()),g[k]);e.set("callback",c+".maps."+q);'
    'a.src=`https://maps.\${c}apis.com/maps/api/js?`+e;d[q]=f;'
    'a.onerror=()=>h=n(Error(p+" could not load."));'
    'a.nonce=m.querySelector("script[nonce]")?.nonce||"";m.head.append(a)}));'
    'd[l]?console.warn(p+" only loads once. Ignoring:",g):'
    'd[l]=(f,...n)=>r.add(f)&&u().then(()=>d[l](f,...n))})'
    '({key: ${jsonEncode(apiKey)}, v: ${jsonEncode(version)}});';
