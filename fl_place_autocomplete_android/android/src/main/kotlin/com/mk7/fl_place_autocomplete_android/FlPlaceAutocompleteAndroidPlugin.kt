package com.mk7.fl_place_autocomplete_android

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import com.google.android.gms.common.api.ApiException
import com.google.android.libraries.places.api.Places
import com.google.android.libraries.places.api.model.AutocompleteSessionToken
import com.google.android.libraries.places.api.model.PhotoMetadata
import com.google.android.libraries.places.api.net.FetchPlaceRequest
import com.google.android.libraries.places.api.net.FetchResolvedPhotoUriRequest
import com.google.android.libraries.places.api.net.FindAutocompletePredictionsRequest
import com.google.android.libraries.places.api.net.PlacesClient
import io.flutter.embedding.engine.plugins.FlutterPlugin
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.tasks.await

/**
 * Places SDK for Android (New) implementation of the Pigeon [PlacesHostApi].
 *
 * The API key is the one Dart sends with [initialize] (from `--dart-define`), falling
 * back to the `com.google.android.geo.API_KEY` manifest meta-data. If another plugin
 * already initialized Places, that initialization (and its key) is reused.
 * Note: the Android SDK has no per-request language; results use the locale the
 * SDK was initialized with (the device/app locale), so `languageCode` is ignored.
 */
class FlPlaceAutocompleteAndroidPlugin : FlutterPlugin, PlacesHostApi {
    private lateinit var context: Context
    private var client: PlacesClient? = null
    /** Key sent by Dart in [initialize]; null/blank means "use the manifest". */
    private var dartApiKey: String? = null
    private val sessions = SessionStore { AutocompleteSessionToken.newInstance() }
    private val photos = PhotoStore<PhotoMetadata>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        PlacesHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        PlacesHostApi.setUp(binding.binaryMessenger, null)
    }

    private fun manifestApiKey(): String? {
        val pm = context.packageManager
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getApplicationInfo(context.packageName, PackageManager.ApplicationInfoFlags.of(PackageManager.GET_META_DATA.toLong()))
        } else {
            @Suppress("DEPRECATION")
            pm.getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)
        }
        return info.metaData?.getString(API_KEY_META_DATA)
    }

    private fun placesClient(): PlacesClient {
        client?.let { return it }
        if (!Places.isInitialized()) {
            val key = KeyResolver.pick(dartApiKey, manifestApiKey())
                ?: throw FlutterError("invalidApiKey", KeyResolver.MISSING_KEY_MESSAGE, null)
            Places.initializeWithNewPlacesApiEnabled(context, key)
        }
        return Places.createClient(context).also { client = it }
    }

    /** Runs [body], translating SDK failures into [FlutterError]s with Dart error codes. */
    private suspend fun <T> guarded(body: suspend () -> T): T = try {
        body()
    } catch (e: CancellationException) {
        throw e
    } catch (e: FlutterError) {
        throw e
    } catch (e: ApiException) {
        throw FlutterError(ErrorMapper.codeFor(e.statusCode), e.message, null)
    } catch (e: IllegalArgumentException) {
        throw FlutterError("invalidRequest", e.message, null)
    } catch (e: Exception) {
        throw FlutterError("unknown", e.message, null)
    }

    override suspend fun initialize(apiKey: String?) {
        dartApiKey = apiKey
        guarded { placesClient() }
    }

    override fun disposeSession(sessionId: String) {
        sessions.remove(sessionId)
    }

    override suspend fun findPredictions(input: String, sessionId: String?, options: OptionsMsg): List<PredictionMsg> = guarded {
        val builder = FindAutocompletePredictionsRequest.builder().setQuery(input)
        sessions.getOrNull(sessionId)?.let { builder.setSessionToken(it) }
        options.locationBias?.toBias()?.let { builder.setLocationBias(it) }
        options.locationRestriction?.let { builder.setLocationRestriction(it.toRectangle()) }
        options.origin?.let { builder.setOrigin(it.toLatLng()) }
        if (options.includedPrimaryTypes.isNotEmpty()) builder.setTypesFilter(options.includedPrimaryTypes)
        if (options.includedRegionCodes.isNotEmpty()) builder.setCountries(options.includedRegionCodes)
        options.regionCode?.let { builder.setRegionCode(it) }
        options.inputOffset?.let { builder.setInputOffset(it.toInt()) }
        // options.languageCode: no per-request language on Android (see class doc).
        placesClient().findAutocompletePredictions(builder.build()).await()
            .autocompletePredictions.map { it.toMsg() }
    }

    override suspend fun fetchPlace(
        placeId: String,
        sessionId: String?,
        fields: List<String>,
        languageCode: String?,
        regionCode: String?,
    ): PlaceMsg = guarded {
        val placeFields = fields.mapNotNull { fieldFor(it) }.distinct()
        val builder = FetchPlaceRequest.builder(placeId, placeFields)
        sessions.getOrNull(sessionId)?.let { builder.setSessionToken(it) }
        regionCode?.let { builder.setRegionCode(it) }
        val place = placesClient().fetchPlace(builder.build()).await().place
        // Place Details ends the session, but only on success: a failed fetch keeps it usable.
        sessionId?.let { sessions.remove(it) }
        place.toMsg(fields.toSet(), photos)
    }

    override suspend fun fetchPhoto(ref: PhotoRefMsg, maxWidth: Long?, maxHeight: Long?): PhotoDataMsg = guarded {
        val metadata = photos.get(ref.id)
            ?: throw FlutterError("notFound", "Unknown photo id ${ref.id}; fetch the place again.", null)
        val builder = FetchResolvedPhotoUriRequest.builder(metadata)
        maxWidth?.let { builder.setMaxWidth(it.toInt()) }
        maxHeight?.let { builder.setMaxHeight(it.toInt()) }
        val response = placesClient().fetchResolvedPhotoUri(builder.build()).await()
        PhotoDataMsg(bytes = null, uri = response.uri?.toString())
    }

    private companion object {
        const val API_KEY_META_DATA = "com.google.android.geo.API_KEY"
    }
}
