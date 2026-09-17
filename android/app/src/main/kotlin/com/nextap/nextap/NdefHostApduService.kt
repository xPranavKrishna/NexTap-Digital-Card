package com.nextap.nextap

import android.nfc.cardemulation.HostApduService
import android.os.Bundle

/**
 * Makes this phone look like a plain NDEF Type 4 NFC tag holding one URL.
 *
 * Why this and not "Android Beam": Beam was removed in Android 10. HCE is the
 * only way left for a phone to push a link to another phone over NFC, and the
 * big win is that the RECEIVING phone needs nothing but NFC switched on - the
 * system NFC reader sees a normal tag and opens the URL.
 *
 * The APDU flow a reader uses:
 *   1. SELECT by name, AID D2760000850101   (the NDEF application)
 *   2. SELECT file E103 (capability container) + READ BINARY
 *   3. SELECT file E104 (NDEF file) + READ BINARY  -> 2 byte length + message
 */
class NdefHostApduService : HostApduService() {

    private var selectedFile = FILE_NONE

    override fun processCommandApdu(apdu: ByteArray?, extras: Bundle?): ByteArray {
        if (apdu == null || apdu.size < 4) return SW_FAIL

        // --- SELECT application by AID -------------------------------------
        if (apdu[0] == 0x00.toByte() &&
            apdu[1] == 0xA4.toByte() &&
            apdu[2] == 0x04.toByte()
        ) {
            selectedFile = FILE_NONE
            return if (enabled) SW_OK else SW_FILE_NOT_FOUND
        }

        // --- SELECT file by identifier -------------------------------------
        if (apdu.size >= 7 &&
            apdu[0] == 0x00.toByte() &&
            apdu[1] == 0xA4.toByte() &&
            apdu[2] == 0x00.toByte()
        ) {
            val fileId = ((apdu[5].toInt() and 0xFF) shl 8) or (apdu[6].toInt() and 0xFF)
            return when (fileId) {
                0xE103 -> { selectedFile = FILE_CC; SW_OK }
                0xE104 -> { selectedFile = FILE_NDEF; SW_OK }
                else -> SW_FILE_NOT_FOUND
            }
        }

        // --- READ BINARY ----------------------------------------------------
        if (apdu.size >= 5 && apdu[0] == 0x00.toByte() && apdu[1] == 0xB0.toByte()) {
            val offset = ((apdu[2].toInt() and 0xFF) shl 8) or (apdu[3].toInt() and 0xFF)
            var le = apdu[4].toInt() and 0xFF
            if (le == 0) le = 256

            val file = when (selectedFile) {
                FILE_CC -> CC_FILE
                FILE_NDEF -> ndefFile
                else -> return SW_FAIL
            }

            if (offset >= file.size) return SW_END_OF_FILE
            val end = minOf(offset + le, file.size)
            return file.copyOfRange(offset, end) + SW_OK
        }

        return SW_FAIL
    }

    override fun onDeactivated(reason: Int) {
        selectedFile = FILE_NONE
    }

    companion object {
        private const val FILE_NONE = 0
        private const val FILE_CC = 1
        private const val FILE_NDEF = 2

        private val SW_OK = byteArrayOf(0x90.toByte(), 0x00)
        private val SW_FAIL = byteArrayOf(0x6F.toByte(), 0x00)
        private val SW_FILE_NOT_FOUND = byteArrayOf(0x6A.toByte(), 0x82.toByte())
        private val SW_END_OF_FILE = byteArrayOf(0x6B.toByte(), 0x00)

        /**
         * Capability Container:
         * 000F      CCLEN
         * 20        mapping version 2.0
         * 003B      max R-APDU
         * 0034      max C-APDU
         * 04 06     NDEF file control TLV
         * E104      file id
         * 0400      max NDEF size (1024)
         * 00        read access: free
         * FF        write access: never
         */
        private val CC_FILE = byteArrayOf(
            0x00, 0x0F, 0x20, 0x00, 0x3B, 0x00, 0x34,
            0x04, 0x06, 0xE1.toByte(), 0x04, 0x04, 0x00, 0x00, 0xFF.toByte()
        )

        @Volatile
        private var ndefFile: ByteArray = byteArrayOf(0x00, 0x00)

        @Volatile
        private var enabled = false

        /** Call with null to stop emulating. */
        @JvmStatic
        fun setUrl(url: String?) {
            if (url.isNullOrEmpty()) {
                enabled = false
                ndefFile = byteArrayOf(0x00, 0x00)
            } else {
                ndefFile = buildNdefFile(url)
                enabled = true
            }
        }

        private fun buildNdefFile(url: String): ByteArray {
            val record = buildUriRecord(url)
            return byteArrayOf(
                ((record.size shr 8) and 0xFF).toByte(),
                (record.size and 0xFF).toByte()
            ) + record
        }

        /** Single well-known URI record, short record form. */
        private fun buildUriRecord(url: String): ByteArray {
            val prefixes = listOf(
                "https://www." to 0x02,
                "http://www." to 0x01,
                "https://" to 0x04,
                "http://" to 0x03,
                "tel:" to 0x05,
                "mailto:" to 0x06
            )
            var code = 0x00
            var rest = url
            for ((p, c) in prefixes) {
                if (url.startsWith(p)) {
                    code = c
                    rest = url.substring(p.length)
                    break
                }
            }
            val payload = byteArrayOf(code.toByte()) + rest.toByteArray(Charsets.UTF_8)
            // MB | ME | SR | TNF=well known  => 0xD1
            return byteArrayOf(
                0xD1.toByte(), 0x01, payload.size.toByte(), 'U'.code.toByte()
            ) + payload
        }
    }
}