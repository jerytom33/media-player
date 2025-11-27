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
	private val sessionEffects = mutableMapOf<Int, Triple<Equalizer?, BassBoost?, Virtualizer?>>()
	private var currentSessionId: Int? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
			when (call.method) {
				"setAudioSessionId" -> {
					val sid = call.argument<Int>("sessionId") ?: 0
					setAudioSessionId(sid)
					result.success(null)
				}
				"setBands" -> {
					val gains = call.argument<List<Double>>("gains") ?: listOf()
					val sid = call.argument<Int>("sessionId")
					setBands(gains, sid)
					result.success(null)
				}
				"setEnabled" -> {
					val enabled = call.argument<Boolean>("enabled") ?: false
					val sid = call.argument<Int>("sessionId")
					setEnabled(enabled, sid)
					result.success(null)
				}
				"setBassBoost" -> {
					val strength = call.argument<Double>("strength") ?: 0.0
					val sid = call.argument<Int>("sessionId")
					setBassBoost(strength, sid)
					result.success(null)
				}
				"setVirtualizer" -> {
					val strength = call.argument<Double>("strength") ?: 0.0
					val sid = call.argument<Int>("sessionId")
					setVirtualizer(strength, sid)
					result.success(null)
				}
				else -> result.notImplemented()
			}
		}
	}

	private fun setAudioSessionId(sid: Int) {
		if (sid <= 0) {
			currentSessionId = null
			return
		}
		currentSessionId = sid
		// Create effect instances for the session if not present
		if (!sessionEffects.containsKey(sid)) {
			val eq = Equalizer(0, sid)
			eq.enabled = true
			val bb = BassBoost(0, sid)
			bb.enabled = true
			val v = Virtualizer(0, sid)
			v.enabled = true
			sessionEffects[sid] = Triple(eq, bb, v)
		}
	}

	private fun setBands(gains: List<Double>, sid: Int?) {
		val targetSid = sid ?: currentSessionId
		val triple = targetSid?.let { sessionEffects[it] }
		val eq = triple?.first
		eq?.let { eq ->
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

	private fun setEnabled(enabled: Boolean, sid: Int?) {
		if (sid != null) {
			sessionEffects[sid]?.let { (eq, bb, v) ->
				eq?.enabled = enabled
				bb?.enabled = enabled
				v?.enabled = enabled
			}
		} else {
			sessionEffects.values.forEach { (eq, bb, v) ->
				eq?.enabled = enabled
				bb?.enabled = enabled
				v?.enabled = enabled
			}
		}
	}

	private fun setBassBoost(strength: Double, sid: Int?) {
		val target = sid ?: currentSessionId
		val triple = target?.let { sessionEffects[it] }
		val bb = triple?.second
		bb?.let { bb ->
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

	private fun setVirtualizer(strength: Double, sid: Int?) {
		val target = sid ?: currentSessionId
		val triple = target?.let { sessionEffects[it] }
		val v = triple?.third
		v?.let { v ->
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

	private fun releaseEffects(sessionId: Int? = null) {
		if (sessionId != null) {
			sessionEffects[sessionId]?.let { (eq, bb, v) ->
				try { eq?.release() } catch (_: Exception) {}
				try { bb?.release() } catch (_: Exception) {}
				try { v?.release() } catch (_: Exception) {}
			}
			sessionEffects.remove(sessionId)
		} else {
			// release all
			sessionEffects.values.forEach { (eq, bb, v) ->
				try { eq?.release() } catch (_: Exception) {}
				try { bb?.release() } catch (_: Exception) {}
				try { v?.release() } catch (_: Exception) {}
			}
			sessionEffects.clear()
		}
	}

	override fun onDestroy() {
		releaseEffects()
		super.onDestroy()
	}
}
