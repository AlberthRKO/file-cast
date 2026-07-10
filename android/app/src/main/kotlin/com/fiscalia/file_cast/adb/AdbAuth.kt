package com.fiscalia.file_cast.adb

import android.content.Context
import android.content.SharedPreferences
import android.util.Base64
import android.util.Log
import java.math.BigInteger
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.KeyFactory
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.SecureRandom
import java.security.Signature
import java.security.interfaces.RSAPublicKey
import java.security.spec.PKCS8EncodedKeySpec
import java.security.spec.X509EncodedKeySpec

class AdbAuth(private val context: Context) {

    companion object {
        private const val TAG = "AdbAuth"
        private const val PREFS_NAME = "adb_auth_prefs"
        private const val KEY_PRIVATE_KEY = "private_key"
        private const val KEY_PUBLIC_KEY = "public_key"
        private const val KEY_KEY_PAIR = "key_pair_exists"
        private const val KEY_SIZE = 2048
        private const val MODULUS_SIZE = 256
        private const val MODULUS_SIZE_WORDS = MODULUS_SIZE / 4  // 64
    }

    private val prefs: SharedPreferences by lazy {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    private var currentKeyPair: KeyPair? = null

    fun init(): KeyPair {
        Log.d(TAG, "=== AdbAuth.init() ===")
        val existing = loadKeyPair()
        if (existing != null) {
            Log.d(TAG, "Loaded existing keypair, fingerprint: ${getKeyFingerprint()}")
            currentKeyPair = existing
            return existing
        }
        Log.d(TAG, "Generating new keypair...")
        val newKeyPair = generateKeyPair()
        saveKeyPair(newKeyPair)
        currentKeyPair = newKeyPair
        Log.d(TAG, "New keypair generated, fingerprint: ${getKeyFingerprint()}")
        return newKeyPair
    }

    private fun generateKeyPair(): KeyPair {
        Log.d(TAG, "Generating RSA ${KEY_SIZE}-bit keypair...")
        val generator = KeyPairGenerator.getInstance("RSA")
        generator.initialize(KEY_SIZE, SecureRandom())
        return generator.generateKeyPair()
    }

    /**
     * Sign token with NONEwithRSA.
     * The device token is 20 raw bytes. adbd verifies with
     * RSA_verify(NID_sha1, token, ...) which hashes internally.
     */
    fun signToken(token: ByteArray): ByteArray? {
        val keyPair = currentKeyPair ?: return null
        Log.d(TAG, "Signing token: ${token.size} bytes with NONEwithRSA")
        return try {
            val signature = Signature.getInstance("NONEwithRSA")
            signature.initSign(keyPair.private)
            signature.update(token)
            val sig = signature.sign()
            Log.d(TAG, "Signature: ${sig.size} bytes")
            sig
        } catch (e: Exception) {
            Log.e(TAG, "Failed to sign token: ${e.message}", e)
            null
        }
    }

    /**
     * Build the public key in android_pubkey binary struct format.
     * This is the format adbd uses to store keys in /data/misc/adb/adb_keys
     * and to verify AUTH signatures.
     *
     * Struct (524 bytes for RSA-2048):
     *   modulus_size_words[4] - 64 (256/4)
     *   n0inv[4]              - Montgomery reduction: -1/modulus[0] mod 2^32
     *   modulus[256]          - RSA modulus, little-endian
     *   rr[256]              - Montgomery reduction: 2^4096 mod modulus, little-endian
     *   exponent[4]          - RSA public exponent (usually 65537)
     */
    fun getAndroidPublicKeyRaw(): ByteArray? {
        val keyPair = currentKeyPair ?: run {
            Log.e(TAG, "No keypair available")
            return null
        }
        val rsa = keyPair.public as? RSAPublicKey ?: run {
            Log.e(TAG, "Public key is not RSAPublicKey")
            return null
        }

        return try {
            val modulus = rsa.modulus
            val exponent = rsa.publicExponent

            // Modulus: zero-padded to MODULUS_SIZE bytes, then reversed to little-endian
            val modulusBytes = modulus.toByteArray()
            val paddedModulus = ByteArray(MODULUS_SIZE)
            val copyLen = minOf(modulusBytes.size, MODULUS_SIZE)
            System.arraycopy(modulusBytes, modulusBytes.size - copyLen, paddedModulus, MODULUS_SIZE - copyLen, copyLen)
            // Reverse to little-endian (LSB first)
            paddedModulus.reverse()

            Log.d(TAG, "Modulus: ${modulusBytes.size} bytes, padded to $MODULUS_SIZE, reversed to LE")

            // n0inv: -1/mod[0] mod 2^32 (Montgomery reduction)
            // After reversal, mod[0] is the least significant byte
            val n0inv = computeN0inv(paddedModulus)
            Log.d(TAG, "n0inv: $n0inv")

            // rr: 2^(MODULUS_SIZE*16) mod modulus (Montgomery reduction)
            val rrBytes = computeRR(modulus, MODULUS_SIZE)
            Log.d(TAG, "rr: ${rrBytes.size} bytes")

            // Exponent: 4 bytes, little-endian
            val expValue = exponent.toInt()
            val expBytes = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(expValue).array()
            Log.d(TAG, "Exponent: $expValue (${exponent.bitLength()} bits)")

            // Build android_pubkey struct (524 bytes)
            val result = ByteArray(4 + 4 + MODULUS_SIZE + MODULUS_SIZE + 4)
            var offset = 0

            // modulus_size_words (4 bytes, little-endian) = 64
            val sizeWords = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(MODULUS_SIZE_WORDS).array()
            System.arraycopy(sizeWords, 0, result, offset, 4)
            offset += 4

            // n0inv (4 bytes, little-endian)
            System.arraycopy(n0inv, 0, result, offset, 4)
            offset += 4

            // modulus (256 bytes, little-endian)
            System.arraycopy(paddedModulus, 0, result, offset, MODULUS_SIZE)
            offset += MODULUS_SIZE

            // rr (256 bytes, little-endian)
            System.arraycopy(rrBytes, 0, result, offset, MODULUS_SIZE)
            offset += MODULUS_SIZE

            // exponent (4 bytes, little-endian)
            System.arraycopy(expBytes, 0, result, offset, 4)
            offset += 4

            Log.d(TAG, "android_pubkey struct: ${result.size} bytes")
            result
        } catch (e: Exception) {
            Log.e(TAG, "Failed to generate public key: ${e.message}", e)
            null
        }
    }

    /**
     * Get the public key as a base64-encoded string.
     * This is the format sent in AUTH_RSAPUBLICKEY wire packets
     * and stored in /data/misc/adb/adb_keys.
     */
    fun getAndroidPublicKeyBase64(): String? {
        val raw = getAndroidPublicKeyRaw() ?: return null
        return android.util.Base64.encodeToString(raw, android.util.Base64.NO_WRAP)
    }

    /**
     * Compute n0inv = -1/mod[0] mod 2^32
     * This is the Montgomery reduction parameter.
     * mod[0] is the least significant byte (first byte after little-endian reversal).
     */
    private fun computeN0inv(modulus: ByteArray): ByteArray {
        // mod[0] is the least significant byte (after LE reversal)
        val mod0 = BigInteger.valueOf((modulus[0].toInt() and 0xFF).toLong())
        val two32 = BigInteger.ONE.shiftLeft(32)

        // n0inv = -1/mod[0] mod 2^32
        val n0inv = two32.subtract(mod0.modInverse(two32))
        return n0inv.toByteArray().let { arr ->
            // Pad to 4 bytes little-endian
            val padded = ByteArray(4)
            val copyLen = minOf(arr.size, 4)
            System.arraycopy(arr, arr.size - copyLen, padded, 4 - copyLen, copyLen)
            padded
        }
    }

    /**
     * Compute rr = 2^(modulusSize*8*2) mod modulus
     * This is the Montgomery reduction parameter.
     * Result is stored in little-endian byte order.
     */
    private fun computeRR(modulus: BigInteger, modulusSize: Int): ByteArray {
        val bitSize = modulusSize * 16L  // 2 * modulusSize * 8
        // rr = 2^bitSize mod modulus
        val rr = BigInteger.valueOf(2).modPow(BigInteger.valueOf(bitSize), modulus)

        val rrBytes = rr.toByteArray()
        val padded = ByteArray(MODULUS_SIZE)
        val copyLen = minOf(rrBytes.size, MODULUS_SIZE)
        System.arraycopy(rrBytes, rrBytes.size - copyLen, padded, MODULUS_SIZE - copyLen, copyLen)
        // Reverse to little-endian
        padded.reverse()
        return padded
    }

    private fun saveKeyPair(keyPair: KeyPair) {
        val editor = prefs.edit()
        editor.putString(KEY_PRIVATE_KEY, Base64.encodeToString(keyPair.private.encoded, Base64.NO_WRAP))
        editor.putString(KEY_PUBLIC_KEY, Base64.encodeToString(keyPair.public.encoded, Base64.NO_WRAP))
        editor.putBoolean(KEY_KEY_PAIR, true)
        editor.apply()
    }

    private fun loadKeyPair(): KeyPair? {
        if (!prefs.getBoolean(KEY_KEY_PAIR, false)) return null

        val privateBase64 = prefs.getString(KEY_PRIVATE_KEY, null) ?: return null
        val publicBase64 = prefs.getString(KEY_PUBLIC_KEY, null) ?: return null

        return try {
            val privateBytes = Base64.decode(privateBase64, Base64.NO_WRAP)
            val publicBytes = Base64.decode(publicBase64, Base64.NO_WRAP)

            val privateKey = KeyFactory.getInstance("RSA").generatePrivate(PKCS8EncodedKeySpec(privateBytes))
            val publicKey = KeyFactory.getInstance("RSA").generatePublic(X509EncodedKeySpec(publicBytes))

            KeyPair(publicKey, privateKey)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load keypair: ${e.message}", e)
            null
        }
    }

    fun clearKeyPair() {
        prefs.edit().clear().apply()
        currentKeyPair = null
    }

    fun getKeyFingerprint(): String? {
        val keyPair = currentKeyPair ?: return null
        return try {
            val md = java.security.MessageDigest.getInstance("SHA-256")
            val digest = md.digest(keyPair.public.encoded)
            digest.joinToString(":") { "%02X".format(it) }
        } catch (e: Exception) {
            null
        }
    }
}
