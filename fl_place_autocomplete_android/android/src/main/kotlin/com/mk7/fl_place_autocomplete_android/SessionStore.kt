package com.mk7.fl_place_autocomplete_android

/**
 * Maps Dart-side session ids to native session tokens.
 *
 * A token is created lazily on first use and lives until [remove] is called
 * (on a successful Place Details fetch or when Dart disposes the session).
 */
class SessionStore<T : Any>(private val factory: () -> T) {
    private val tokens = HashMap<String, T>()

    @Synchronized
    fun getOrCreate(id: String): T = tokens.getOrPut(id, factory)

    /** Returns the token for [id], creating it if needed; `null` when [id] is `null`. */
    @Synchronized
    fun getOrNull(id: String?): T? = id?.let { getOrCreate(it) }

    @Synchronized
    fun remove(id: String) {
        tokens.remove(id)
    }
}
