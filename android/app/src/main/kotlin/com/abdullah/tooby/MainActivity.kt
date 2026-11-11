package com.abdullah.tooby

import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.Icon
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Rational
import androidx.lifecycle.Lifecycle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.abdullah.tooby/pip"
    private val actionBroadcast = "com.abdullah.tooby.PIP_ACTION"

    private var channel: MethodChannel? = null
    private var pipReady = false
    private var isPlaying = false
    private var hasNext = false
    private var aspect = Rational(16, 9)
    private var receiverRegistered = false

    // ── PIP button presses ──────────────────────────────────────────────────

    private val pipReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = intent?.getStringExtra("action") ?: return
            channel?.invokeMethod("pipAction", action)
        }
    }

    /** Only listen for PIP button intents while actually in PIP. */
    private fun registerPipReceiver() {
        if (receiverRegistered) return
        val filter = IntentFilter(actionBroadcast)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(pipReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(pipReceiver, filter)
        }
        receiverRegistered = true
    }

    private fun unregisterPipReceiver() {
        if (!receiverRegistered) return
        try {
            unregisterReceiver(pipReceiver)
        } catch (_: Exception) {
        }
        receiverRegistered = false
    }

    // ── Audio focus ─────────────────────────────────────────────────────────

    private val audioManager by lazy { getSystemService(Context.AUDIO_SERVICE) as AudioManager }
    private var focusRequest: AudioFocusRequest? = null

    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        when (change) {
            AudioManager.AUDIOFOCUS_LOSS,
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                channel?.invokeMethod("pipAction", "audioFocusLost")
            }
        }
    }

    private fun requestAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = focusRequest ?: AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE)
                        .build()
                )
                .setOnAudioFocusChangeListener(focusListener)
                .build()
                .also { focusRequest = it }
            audioManager.requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                focusListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN
            )
        }
    }

    private fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(focusListener)
        }
    }

    override fun onDestroy() {
        unregisterPipReceiver()
        abandonAudioFocus()
        super.onDestroy()
    }

    // ── Flutter channel ─────────────────────────────────────────────────────

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "setPipState" -> {
                        pipReady = call.argument<Boolean>("ready") ?: false
                        isPlaying = call.argument<Boolean>("playing") ?: false
                        hasNext = call.argument<Boolean>("hasNext") ?: false
                        val w = call.argument<Int>("width") ?: 16
                        val h = call.argument<Int>("height") ?: 9
                        aspect = clampAspect(w, h)
                        applyPipParams()
                        result.success(null)
                    }
                    "enterPip" -> result.success(enterPipMode())
                    "requestAudioFocus" -> {
                        requestAudioFocus()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    // ── PIP ─────────────────────────────────────────────────────────────────

    // Android only accepts aspect ratios between 1:2.39 and 2.39:1.
    private fun clampAspect(w: Int, h: Int): Rational {
        if (w <= 0 || h <= 0) return Rational(16, 9)
        val ratio = w.toDouble() / h.toDouble()
        return when {
            ratio > 2.39 -> Rational(239, 100)
            ratio < 1 / 2.39 -> Rational(100, 239)
            else -> Rational(w, h)
        }
    }

    private fun pendingAction(name: String, code: Int): PendingIntent {
        val intent = Intent(actionBroadcast).setPackage(packageName).putExtra("action", name)
        return PendingIntent.getBroadcast(
            this, code, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun whiteIcon(resId: Int): Icon =
        Icon.createWithResource(this, resId).setTint(Color.WHITE)

    private fun buildParams(): PictureInPictureParams? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return null

        // Bottom row: previous · play/pause · next
        val previous = RemoteAction(
            whiteIcon(android.R.drawable.ic_media_previous),
            "Previous", "Previous video", pendingAction("previous", 1)
        )
        val playPause = if (isPlaying) RemoteAction(
            whiteIcon(android.R.drawable.ic_media_pause),
            "Pause", "Pause", pendingAction("pause", 2)
        ) else RemoteAction(
            whiteIcon(android.R.drawable.ic_media_play),
            "Play", "Play", pendingAction("play", 3)
        )
        val next = RemoteAction(
            whiteIcon(android.R.drawable.ic_media_next),
            "Next", "Next video", pendingAction("next", 4)
        ).apply { isEnabled = hasNext }

        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(aspect)
            .setActions(listOf(previous, playPause, next))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Auto-enter PIP on Home / app switch, but only while playing.
            builder.setAutoEnterEnabled(pipReady)
            builder.setSeamlessResizeEnabled(true)
        }
        return builder.build()
    }

    private fun applyPipParams() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        try {
            buildParams()?.let { setPictureInPictureParams(it) }
        } catch (_: Exception) {
        }
    }

    private fun enterPipMode(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return try {
            val params = buildParams() ?: return false
            enterPictureInPictureMode(params)
        } catch (_: Exception) {
            false
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Android 12+ handles this through setAutoEnterEnabled.
        if (pipReady && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            enterPipMode()
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        if (isInPictureInPictureMode) {
            registerPipReceiver()
        } else {
            unregisterPipReceiver()
            // Expand (↗↙) brings the activity back to RESUMED right away;
            // close (X) stops it instead. Check shortly after to tell them apart.
            Handler(Looper.getMainLooper()).postDelayed({
                if (!lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) {
                    channel?.invokeMethod("pipAction", "closed")
                }
            }, 400)
        }
        channel?.invokeMethod("onPipChanged", isInPictureInPictureMode)
    }
}
