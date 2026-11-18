package com.dabbler.dabblerapp.liveactivity

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

private class MapKv : LaKv {
    private val m = ConcurrentHashMap<String, Any>()
    override fun getString(key: String) = m[key] as? String
    override fun getLong(key: String) = m[key] as? Long
    override fun getBoolean(key: String) = m[key] as? Boolean ?: false
    override fun keys(): Set<String> = m.keys.toSet()
    override fun edit(block: LaKvEditor.() -> Unit) {
        object : LaKvEditor {
            override fun putString(key: String, value: String) { m[key] = value }
            override fun putLong(key: String, value: Long) { m[key] = value }
            override fun putBoolean(key: String, value: Boolean) { m[key] = value }
            override fun remove(key: String) { m.remove(key) }
        }.block()
    }
}

class LiveActivityStoreTest {
    private fun session(v: Long) = LaSession("s1", "e1", v, 7, "{}")

    @Test fun concurrentAppliesOfTheSameVersionHaveOneWinner() {
        repeat(50) {
            val store = LiveActivityStore(MapKv())
            val wins = AtomicInteger()
            val threads = 16
            val pool = Executors.newFixedThreadPool(threads)
            val go = CountDownLatch(1)
            repeat(threads) {
                pool.execute {
                    go.await()
                    store.applyIfNewer("s1", 5) {
                        Thread.yield()
                        store.put(session(5))
                        wins.incrementAndGet()
                    }
                }
            }
            go.countDown()
            pool.shutdown()
            assertTrue(pool.awaitTermination(10, TimeUnit.SECONDS))
            assertEquals(1, wins.get())
            assertEquals(5L, store.heldVersion("s1"))
        }
    }

    @Test fun olderOrEqualVersionIsRejectedAfterForget() {
        val store = LiveActivityStore(MapKv())
        store.applyIfNewer("s1", 3) { store.put(session(3)) }
        store.forget("s1")
        assertEquals(null, store.applyIfNewer("s1", 3) { "ran" })
        assertEquals("ran", store.applyIfNewer("s1", 4) { "ran" })
    }

    @Test fun unshownFlagRoundTrips() {
        val store = LiveActivityStore(MapKv())
        store.put(session(2).copy(shown = false))
        assertFalse(store.get("s1")!!.shown)
        assertEquals(2L, store.heldVersion("s1"))
    }
}

class LaLocaleTest {
    @Test fun appChoiceWinsOverDevice() {
        assertEquals("ar", LaLocale.pick("ar", "en"))
        assertEquals("en", LaLocale.pick("en", "ar"))
        assertEquals("ar", LaLocale.pick("AR", "en"))
        assertEquals("ar", LaLocale.pick("ar_EG", "en"))
    }

    @Test fun unsetOrUnknownFallsBackToDevice() {
        assertEquals("ar", LaLocale.pick(null, "ar"))
        assertEquals("en", LaLocale.pick("fr", "en"))
        assertEquals("ar", LaLocale.pick("", "ar"))
        assertEquals("en", LaLocale.pick(null, "de"))
        assertEquals("en", LaLocale.pick(null, null))
    }

    @Test fun rtlOnlyForArabic() {
        assertTrue(LaLocale.isRtl("ar"))
        assertFalse(LaLocale.isRtl("en"))
    }
}
