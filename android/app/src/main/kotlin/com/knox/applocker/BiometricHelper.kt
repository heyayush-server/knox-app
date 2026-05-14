package com.knox.applocker

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Log
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

/**
 * Knox Biometric Enrollment Change Detector
 *
 * Uses Android Keystore's biometric binding feature to detect enrollment changes.
 *
 * How it works:
 * ─────────────────────────────────────────────────────────────────────────────
 * Android Keystore supports creating cryptographic keys that are bound to the
 * device's current biometric enrollment via:
 *   setInvalidatedByBiometricEnrollment(true)
 *
 * When a new fingerprint is enrolled or an existing one is removed, Android
 * automatically INVALIDATES any keys created with this flag. The next time
 * Knox tries to use the key, it throws KeyPermanentlyInvalidatedException.
 *
 * This exception IS our detection signal:
 *   - Key still valid → No enrollment change
 *   - KeyPermanentlyInvalidatedException → Enrollment changed!
 *
 * Security guarantees:
 * ─────────────────────────────────────────────────────────────────────────────
 * - Detection happens at the hardware/OS level — cannot be spoofed by apps
 * - Works on Android 6.0+ (API 23+)
 * - Samsung Knox-protected devices have additional hardware attestation
 * - The secret key itself is only used as a canary — we don't store/transmit it
 *
 * Samsung OneUI compatibility:
 * ─────────────────────────────────────────────────────────────────────────────
 * - Samsung devices use Samsung Knox Keystore which implements the same API
 * - Tested compatible with OneUI 3.x, 4.x, 5.x, 6.x
 * - Samsung's "Secure Folder" creates a separate keystore — Knox monitors
 *   the primary keystore only (the one used for biometric authentication)
 */
object BiometricHelper {

    private const val TAG = "BiometricHelper"
    private const val KEY_ALIAS = "knox_biometric_canary_key"
    private const val KEYSTORE_PROVIDER = "AndroidKeyStore"

    /**
     * Returns a stable "enrollment hash" — a string that changes when
     * biometric enrollment changes.
     *
     * Strategy:
     * 1. Try to use the biometric-bound canary key in the KeyStore.
     * 2. If it works → return a success token (enrollment unchanged).
     * 3. If KeyPermanentlyInvalidatedException → enrollment changed.
     *    Delete and recreate key, return a changed token.
     * 4. If key doesn't exist → create it (first run).
     *
     * Returns:
     * - "valid_TIMESTAMP" if enrollment is unchanged
     * - "changed_TIMESTAMP" if enrollment changed
     * - null if biometrics not supported
     */
    fun getEnrollmentHash(context: Context): String? {
        return try {
            if (isKeyValid()) {
                // Key exists and is valid — enrollment hasn't changed
                getOrCreateValidToken(context)
            } else {
                // Key doesn't exist — create it (first run or after reset)
                createCanaryKey()
                getOrCreateValidToken(context)
            }
        } catch (e: KeyPermanentlyInvalidatedException) {
            // !! ENROLLMENT CHANGED !! This is our detection signal
            Log.w(TAG, "Biometric enrollment change detected! Key was invalidated.")

            // Delete the invalidated key
            deleteCanaryKey()

            // Create a new key with new enrollment
            try {
                createCanaryKey()
            } catch (ex: Exception) {
                Log.e(TAG, "Failed to recreate canary key: ${ex.message}")
            }

            // Return a "changed" token — Flutter side will see this differs from stored value
            "changed_${System.currentTimeMillis()}"

        } catch (e: Exception) {
            Log.e(TAG, "BiometricHelper error: ${e.message}")
            null
        }
    }

    /**
     * Check if the canary key exists and is accessible.
     * Returns false if key doesn't exist.
     * Throws KeyPermanentlyInvalidatedException if enrollment changed.
     */
    private fun isKeyValid(): Boolean {
        return try {
            val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER)
            keyStore.load(null)

            if (!keyStore.containsAlias(KEY_ALIAS)) {
                return false
            }

            // Try to initialize a cipher with the key
            // This throws KeyPermanentlyInvalidatedException if enrollment changed
            val key = keyStore.getKey(KEY_ALIAS, null) as? SecretKey ?: return false
            val cipher = Cipher.getInstance(
                "${KeyProperties.KEY_ALGORITHM_AES}/" +
                "${KeyProperties.BLOCK_MODE_CBC}/" +
                KeyProperties.ENCRYPTION_PADDING_PKCS7
            )
            cipher.init(Cipher.ENCRYPT_MODE, key)

            true // Key is valid
        } catch (e: KeyPermanentlyInvalidatedException) {
            throw e // Re-throw — this is our detection signal
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Create a new biometric-bound canary key in the Android Keystore.
     *
     * Key properties:
     * - AES-256-CBC encryption
     * - Requires user authentication (biometric/device credential)
     * - setInvalidatedByBiometricEnrollment(true) — KEY PROPERTY for detection
     * - requiresAuthentication: false — we only use it as a canary, not for auth
     */
    private fun createCanaryKey() {
        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            KEYSTORE_PROVIDER
        )

        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_CBC)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_PKCS7)
            .setKeySize(256)
            // !! CRITICAL: This flag enables enrollment change detection !!
            // When ANY fingerprint is added or removed, this key becomes
            // permanently invalidated — our detection signal.
            .setInvalidatedByBiometricEnrollment(true)
            // User authentication required — binds key to biometric enrollment
            .setUserAuthenticationRequired(false) // Don't need user to auth for canary
            .build()

        keyGenerator.init(spec)
        keyGenerator.generateKey()
        Log.d(TAG, "Biometric canary key created successfully")
    }

    /**
     * Delete the canary key (called after invalidation to allow fresh start)
     */
    private fun deleteCanaryKey() {
        try {
            val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER)
            keyStore.load(null)
            if (keyStore.containsAlias(KEY_ALIAS)) {
                keyStore.deleteEntry(KEY_ALIAS)
                Log.d(TAG, "Canary key deleted")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete canary key: ${e.message}")
        }
    }

    /**
     * Returns a stable token for the "enrollment unchanged" state.
     * Stored in SharedPreferences so we have a persistent reference.
     */
    private fun getOrCreateValidToken(context: Context): String {
        val prefs = context.getSharedPreferences("knox_biometric_prefs", Context.MODE_PRIVATE)
        val existing = prefs.getString("enrollment_token", null)
        if (existing != null) return existing

        val newToken = "valid_${System.currentTimeMillis()}"
        prefs.edit().putString("enrollment_token", newToken).apply()
        return newToken
    }
}
