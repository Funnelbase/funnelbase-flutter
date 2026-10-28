package com.funnelbase.sdk.flutter

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri

/**
 * Starts the native SDK at process start, before `Application.onCreate` and long before any Dart.
 *
 * A content provider because it is the earliest code a library runs without the app writing any:
 * Android creates every provider between attaching the Application and calling its `onCreate`.
 * That ordering is the point. A push wakes the process through the app's messaging service, and a
 * tapped notification through the SDK's tap activity — both after `Application.onCreate`, both
 * with no Flutter engine — and each would otherwise find the SDK uninitialised and drop the
 * receipt or the open. It does nothing on an install whose Dart has never called
 * `Analytics.initialize`.
 *
 * It answers no queries; the four data methods are the minimum a provider has to have.
 */
class AnalyticsFlutterInitProvider : ContentProvider() {

    override fun onCreate(): Boolean {
        context?.let(AnalyticsFlutter::startFromStore)
        return true
    }

    override fun query(uri: Uri, projection: Array<out String>?, selection: String?, selectionArgs: Array<out String>?, sortOrder: String?): Cursor? = null

    override fun getType(uri: Uri): String? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?): Int = 0
}
