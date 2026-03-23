package com.aura.anime_updates // Use your actual package name

import com.frostwire.jlibtorrent.Sha1Hash

object TorrentUtils {
    private const val ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

    fun base32ToByteArray(base32: String): ByteArray {
        val cleaned = base32.uppercase().trim()
        val out = ByteArray(20)
        var buffer = 0
        var bitsLeft = 0
        var count = 0

        for (c in cleaned) {
            val val5bit = ALPHABET.indexOf(c)
            if (val5bit == -1) continue
            
            buffer = (buffer shl 5) or val5bit
            bitsLeft += 5
            
            if (bitsLeft >= 8) {
                if (count < 20) {
                    out[count++] = (buffer shr (bitsLeft - 8)).toByte()
                }
                bitsLeft -= 8
            }
        }
        return out
    }

    fun getSha1FromMagnet(magnetUrl: String): Sha1Hash? {
        val raw = magnetUrl.substringAfter("btih:").substringBefore("&").trim()
        return try {
            when (raw.length) {
                32 -> Sha1Hash(base32ToByteArray(raw)) 
                40 -> Sha1Hash(raw)
                else -> null
            }
        } catch (e: Exception) {
            null
        }
    }
}