package com.example.mp3_player

import android.media.audiofx.Equalizer
import android.media.audiofx.BassBoost
import android.media.audiofx.Virtualizer
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "com.example.mp3_player/equalizer"
	private var equalizer: Equalizer? = null
	private var bassBoost: BassBoost? = null
	private var virtualizer: Virtualizer? = null
	private var sessionId: Int = 0

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
			when (call.method) {
				"setAudioSessionId" -> {
					val sid = (call.argument<Int>("sessionId") ?: 0)
					setAudioSessionId(sid)
					result.success(null)
				}
				"setBands" -> {
					val gains = call.argument<List<Double>>("gains") ?: listOf()
					setBands(gains)
					result.success(null)
				}
				"setEnabled" -> {
					val enabled = call.argument<Boolean>("enabled") ?: false
					setEnabled(enabled)
					result.success(null)
				}
				"setBassBoost" -> {
					val strength = call.argument<Double>("strength") ?: 0.0
					setBassBoost(strength)
					result.success(null)
				}
				"setVirtualizer" -> {
					val strength = call.argument<Double>("strength") ?: 0.0
					setVirtualizer(strength)
					result.success(null)
				}
				else -> result.notImplemented()
			}
		}
	}

	private fun setAudioSessionId(sid: Int) {
		sessionId = sid
		releaseEffects()
		if (sessionId >= 0) {
			equalizer = Equalizer(0, sessionId.toInt())
			equalizer?.enabled = true
			bassBoost = BassBoost(0, sessionId.toInt())
			bassBoost?.enabled = true
			virtualizer = Virtualizer(0, sessionId.toInt())
			virtualizer?.enabled = true
		}
	}

	private fun setBands(gains: List<Double>) {
		equalizer?.let { eq ->
			val bandCount = eq.numberOfBands.toInt()
			val range = eq.bandLevelRange
			val min = range[0].toInt()
			val max = range[1].toInt()
			for (i in 0 until bandCount) {
				val db = if (i < gains.size) gains[i] else 0.0
				val milliDb = (db * 100).toInt().coerceIn(min, max)
				try {
					// Use reflection to handle different platform method signatures for setBandLevel
					// Try signature(short, short)
					try {
						val method = eq.javaClass.getMethod("setBandLevel", java.lang.Short::class.javaPrimitiveType, java.lang.Short::class.javaPrimitiveType)
						method.invoke(eq, java.lang.Short.valueOf(i.toShort()), java.lang.Short.valueOf(milliDb.toShort()))
					} catch (_: NoSuchMethodException) {
						// Try signature(int, short)
						try {
							val method = eq.javaClass.getMethod("setBandLevel", java.lang.Integer::class.javaPrimitiveType, java.lang.Short::class.javaPrimitiveType)
							method.invoke(eq, Integer.valueOf(i), java.lang.Short.valueOf(milliDb.toShort()))
						} catch (_: NoSuchMethodException) {
							// Try signature(int, int)
							val method = eq.javaClass.getMethod("setBandLevel", java.lang.Integer::class.javaPrimitiveType, java.lang.Integer::class.javaPrimitiveType)
							method.invoke(eq, Integer.valueOf(i), Integer.valueOf(milliDb))
						}
					}
				} catch (e: Exception) {
					Log.w("Equalizer", "Failed to set band level: $e")
				}
			}
		}
	}

	private fun setEnabled(enabled: Boolean) {
		equalizer?.enabled = enabled
		bassBoost?.enabled = enabled
		virtualizer?.enabled = enabled
	}

	private fun setBassBoost(strength: Double) {
		bassBoost?.let { bb ->
			val s = (strength * 1000).toInt().coerceIn(0, 1000)
			try {
				try {
					val method = bb.javaClass.getMethod("setStrength", java.lang.Short::class.javaPrimitiveType)
					method.invoke(bb, java.lang.Short.valueOf(s.toShort()))
				} catch (_: NoSuchMethodException) {
					val method = bb.javaClass.getMethod("setStrength", java.lang.Integer::class.javaPrimitiveType)
					method.invoke(bb, Integer.valueOf(s))
				}
			} catch (_: Exception) {}
		}
	}

	private fun setVirtualizer(strength: Double) {
		virtualizer?.let { v ->
			val s = (strength * 1000).toInt().coerceIn(0, 1000)
			try {
				try {
					val method = v.javaClass.getMethod("setStrength", java.lang.Short::class.javaPrimitiveType)
					method.invoke(v, java.lang.Short.valueOf(s.toShort()))
				} catch (_: NoSuchMethodException) {
					val method = v.javaClass.getMethod("setStrength", java.lang.Integer::class.javaPrimitiveType)
					method.invoke(v, Integer.valueOf(s))
				}
			} catch (_: Exception) {}
		}
	}

	private fun releaseEffects() {
		try {
			equalizer?.release()
		} catch (_: Exception) {}
		equalizer = null
		try {
			bassBoost?.release()
		} catch (_: Exception) {}
		bassBoost = null
		try {
			virtualizer?.release()
		} catch (_: Exception) {}
		virtualizer = null
	}

	override fun onDestroy() {
		releaseEffects()
		super.onDestroy()
	}
}
