package com.example.family_tracker

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.database.sqlite.SQLiteDatabase
import android.location.Location
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class TrackingForegroundService : Service() {

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private var locationCallback: LocationCallback? = null
    
    private var deviceName: String = "Mobile Device"
    private var jwtToken: String? = null
    private var apiBaseUrl: String? = null
    private var isSyncing = false

    private var syncHandler: Handler? = null
    private var syncRunnable: Runnable? = null

    companion object {
        private const val TAG = "TrackingService"
        private const val CHANNEL_ID = "LocationTrackingChannel"
        private const val NOTIFICATION_ID = 12345
        var isServiceRunning = false
    }

    override fun onCreate() {
        super.onCreate()
        isServiceRunning = true
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val prefs = getSharedPreferences("family_tracker_prefs", Context.MODE_PRIVATE)

        if (intent != null) {
            deviceName = intent.getStringExtra("deviceName") ?: "Mobile Device"
            jwtToken = intent.getStringExtra("jwtToken")
            apiBaseUrl = intent.getStringExtra("apiBaseUrl")

            // Persist parameters to SharedPreferences to survive system service restart
            prefs.edit().apply {
                putString("deviceName", deviceName)
                putString("jwtToken", jwtToken)
                putString("apiBaseUrl", apiBaseUrl)
                putBoolean("tracking_enabled", true)
                apply()
            }
            Log.d(TAG, "Service started via explicit intent. Parameters persisted.")
        } else {
            // Service restarted by OS, restore parameters from SharedPreferences
            deviceName = prefs.getString("deviceName", "Mobile Device") ?: "Mobile Device"
            jwtToken = prefs.getString("jwtToken", null)
            apiBaseUrl = prefs.getString("apiBaseUrl", null)
            Log.d(TAG, "Service restarted by OS. Parameters restored from SharedPreferences.")
        }

        // Persistent notification setup
        val mainIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, mainIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Family Tracker")
            .setContentText("Location tracking is active")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        startForeground(NOTIFICATION_ID, notification)
        startLocationUpdates()
        startPeriodicSync()

        return START_STICKY
    }

    private fun startPeriodicSync() {
        if (syncHandler == null) {
            syncHandler = Handler(Looper.getMainLooper())
            syncRunnable = object : Runnable {
                override fun run() {
                    Log.d(TAG, "Periodic sync timer triggered in foreground service.")
                    triggerSync()
                    syncHandler?.postDelayed(this, 5000) // Schedule next sync in 5 seconds
                }
            }
            syncHandler?.post(syncRunnable!!)
            Log.d(TAG, "Periodic sync timer initialized.")
        }
    }

    private fun startLocationUpdates() {
        if (locationCallback != null) return

        val locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 5000)
            .setMinUpdateIntervalMillis(5000)
            .build()

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                for (location in locationResult.locations) {
                    Log.d(TAG, "GPS captured: Lat: ${location.latitude}, Lng: ${location.longitude}")
                    saveLocationToDb(location)
                }
                triggerSync()
            }
        }

        try {
            fusedLocationClient.requestLocationUpdates(
                locationRequest,
                locationCallback!!,
                Looper.getMainLooper()
            )
            Log.d(TAG, "Location updates requested successfully.")
        } catch (e: SecurityException) {
            Log.e(TAG, "Failed to request location updates: ${e.message}")
        }
    }

    private fun saveLocationToDb(location: Location) {
        try {
            val dbFile = getDatabasePath("family_tracker.db")
            val db = SQLiteDatabase.openOrCreateDatabase(dbFile, null)

            // Gather metadata
            val batteryStatus = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val level = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
            val batteryPct = if (level >= 0 && scale > 0) (level * 100 / scale) else 100

            val status = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL

            val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val gpsEnabled = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)

            val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val activeNetwork = connectivityManager.activeNetwork
            val capabilities = connectivityManager.getNetworkCapabilities(activeNetwork)
            val internetAvailable = capabilities != null && capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)

            val values = ContentValues().apply {
                put("latitude", location.latitude)
                put("longitude", location.longitude)
                put("accuracy", location.accuracy)
                put("speed", location.speed)
                put("battery_percentage", batteryPct)
                put("charging_status", if (isCharging) 1 else 0)
                put("gps_enabled", if (gpsEnabled) 1 else 0)
                put("internet_available", if (internetAvailable) 1 else 0)
                put("device_name", deviceName)
                put("timestamp", System.currentTimeMillis())
            }

            val rowId = db.insert("locations_cache", null, values)
            db.close()
            Log.d(TAG, "SQLite insert: Row ID: $rowId")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save location to SQLite: ${e.message}")
        }
    }

    private fun triggerSync() {
        if (isSyncing) return
        if (jwtToken == null || apiBaseUrl == null) {
            Log.d(TAG, "Sync aborted: jwtToken or apiBaseUrl is null.")
            return
        }
        isSyncing = true

        Thread {
            try {
                val dbFile = getDatabasePath("family_tracker.db")
                if (!dbFile.exists()) {
                    isSyncing = false
                    return@Thread
                }
                
                val db = SQLiteDatabase.openOrCreateDatabase(dbFile, null)
                
                while (true) {
                    // Check internet availability
                    val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                    val activeNetwork = connectivityManager.activeNetwork
                    val capabilities = connectivityManager.getNetworkCapabilities(activeNetwork)
                    val internetAvailable = capabilities != null && capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)

                    if (!internetAvailable) {
                        Log.d(TAG, "Sync paused: Internet not available.")
                        break
                    }

                    val cursor = db.rawQuery("SELECT * FROM locations_cache ORDER BY timestamp ASC LIMIT 20", null)
                    if (!cursor.moveToFirst()) {
                        cursor.close()
                        break
                    }

                    val ids = mutableListOf<Int>()
                    val pointsArray = JSONArray()

                    val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
                    sdf.timeZone = TimeZone.getTimeZone("UTC")

                    do {
                        val idIndex = cursor.getColumnIndex("id")
                        val latIndex = cursor.getColumnIndex("latitude")
                        val lngIndex = cursor.getColumnIndex("longitude")
                        val accIndex = cursor.getColumnIndex("accuracy")
                        val speedIndex = cursor.getColumnIndex("speed")
                        val batIndex = cursor.getColumnIndex("battery_percentage")
                        val chargeIndex = cursor.getColumnIndex("charging_status")
                        val gpsIndex = cursor.getColumnIndex("gps_enabled")
                        val internetIndex = cursor.getColumnIndex("internet_available")
                        val deviceIndex = cursor.getColumnIndex("device_name")
                        val timeIndex = cursor.getColumnIndex("timestamp")

                        val id = cursor.getInt(idIndex)
                        val lat = cursor.getDouble(latIndex)
                        val lng = cursor.getDouble(lngIndex)
                        val acc = cursor.getFloat(accIndex)
                        val speed = if (cursor.isNull(speedIndex)) null else cursor.getFloat(speedIndex)
                        val bat = if (cursor.isNull(batIndex)) null else cursor.getInt(batIndex)
                        val charge = cursor.getInt(chargeIndex) == 1
                        val gps = cursor.getInt(gpsIndex) == 1
                        val internet = cursor.getInt(internetIndex) == 1
                        val devName = if (cursor.isNull(deviceIndex)) null else cursor.getString(deviceIndex)
                        val timeMs = cursor.getLong(timeIndex)

                        ids.add(id)

                        val point = JSONObject().apply {
                            put("latitude", lat)
                            put("longitude", lng)
                            put("accuracy", acc)
                            if (speed != null) put("speed", speed)
                            if (bat != null) put("batteryPercentage", bat)
                            put("chargingStatus", charge)
                            put("gpsEnabled", gps)
                            put("internetAvailable", internet)
                            put("timestamp", sdf.format(Date(timeMs)))
                            if (devName != null) put("deviceName", devName)
                        }
                        pointsArray.put(point)
                    } while (cursor.moveToNext())

                    cursor.close()

                    // Perform POST request
                    val body = JSONObject().apply {
                        put("points", pointsArray)
                    }.toString()

                    val url = URL("$apiBaseUrl/locations/sync")
                    Log.d(TAG, "Upload attempt: Batch size: ${ids.size}")
                    
                    val conn = url.openConnection() as HttpURLConnection
                    conn.requestMethod = "POST"
                    conn.setRequestProperty("Content-Type", "application/json")
                    conn.setRequestProperty("Authorization", "Bearer $jwtToken")
                    conn.doOutput = true
                    conn.connectTimeout = 5000
                    conn.readTimeout = 5000

                    try {
                        val writer = OutputStreamWriter(conn.outputStream)
                        writer.write(body)
                        writer.flush()
                        writer.close()

                        val responseCode = conn.responseCode
                        Log.d(TAG, "Upload success: Status: $responseCode")

                        if (responseCode == 200 || responseCode == 201) {
                            // Delete sent points
                            val idsStr = ids.joinToString(",")
                            db.execSQL("DELETE FROM locations_cache WHERE id IN ($idsStr)")
                            Log.d(TAG, "Record marked synced: IDs: $idsStr")
                        } else {
                            Log.e(TAG, "Upload failure: status code $responseCode")
                            break
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Retry scheduled. Upload connection failure: ${e.message}")
                        break
                    } finally {
                        conn.disconnect()
                    }
                }
                db.close()
            } catch (e: Exception) {
                Log.e(TAG, "Sync process error: ${e.message}")
            } finally {
                isSyncing = false
            }
        }.start()
    }

    override fun onDestroy() {
        isServiceRunning = false
        // Stop periodic sync timer
        syncRunnable?.let { syncHandler?.removeCallbacks(it) }
        syncHandler = null
        syncRunnable = null

        // Clear persisted parameters on manual stop
        val prefs = getSharedPreferences("family_tracker_prefs", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putBoolean("tracking_enabled", false)
            remove("jwtToken")
            apply()
        }

        if (locationCallback != null) {
            fusedLocationClient.removeLocationUpdates(locationCallback!!)
        }
        Log.d(TAG, "Service destroyed and location updates removed.")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Location Tracking Channel",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }
}
