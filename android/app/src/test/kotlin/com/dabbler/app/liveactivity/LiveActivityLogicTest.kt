package com.dabbler.dabblerapp.liveactivity

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LiveActivityLogicTest {
    private fun content(vararg extra: Pair<String, Any?>): Map<String, Any?> = mapOf(
        "state" to "checkin_open", "state_version" to 3, "event_id" to "e1",
        "event_type" to "game", "start_at" to 2_000L, "checked_in" to false, "role" to "participant",
    ) + extra

    @Test fun versionRuleIsStrictlyHigher() {
        assertTrue(VersionRule.shouldApply(null, 1))
        assertTrue(VersionRule.shouldApply(3, 4))
        assertFalse(VersionRule.shouldApply(3, 3))
        assertFalse(VersionRule.shouldApply(3, 2))
    }

    @Test fun missingRequiredKeyIsInvalid() {
        assertNull(LaContent.fromMap(content() - "event_id"))
        assertNull(LaContent.fromMap(content() - "start_at"))
        assertNull(LaContent.fromMap(content("state_version" to "x")))
    }

    @Test fun stateVersionMayBeAString() {
        assertEquals(7L, LaContent.fromMap(content("state_version" to "7"))!!.stateVersion)
    }

    @Test fun payloadToState() {
        fun ui(vararg e: Pair<String, Any?>) = LaContent.fromMap(content(*e))!!.uiState
        assertEquals(UiState.CHECKIN_OPEN, ui())
        assertEquals(UiState.STARTING_SOON, ui("checked_in" to true))
        assertEquals(UiState.STARTING_SOON, ui("state" to "checked_in"))
        assertEquals(UiState.RUNNING, ui("state" to "scheduled_time_running"))
        assertEquals(UiState.RUNNING, ui("state" to "started"))
        assertEquals(UiState.ENDED, ui("state" to "ended"))
        assertEquals(UiState.ENDED, ui("state" to "scheduled_time_ended"))
        assertEquals(UiState.CANCELLED, ui("state" to "cancelled"))
        assertEquals(UiState.CANCELLED, ui("state" to "ended", "end_reason" to "cancelled"))
    }

    @Test fun checkInOfferedToParticipantOnly() {
        assertTrue(LaContent.fromMap(content())!!.offersCheckIn)
        assertFalse(LaContent.fromMap(content("role" to "organiser"))!!.offersCheckIn)
        assertFalse(LaContent.fromMap(content("checked_in" to true))!!.offersCheckIn)
    }

    @Test fun chip() {
        val c = LaContent.fromMap(content())!!
        assertEquals(ChipKind.COUNTDOWN, c.chip(1_000))
        assertEquals(ChipKind.CHECK_IN, c.chip(2_100))
        assertEquals(ChipKind.CHANGED, LaContent.fromMap(content("change" to "time"))!!.chip(1_000))
        assertEquals(ChipKind.LIVE, LaContent.fromMap(content("state" to "started"))!!.chip(3_000))
    }

    @Test fun countdownMinutesThenHours() {
        assertEquals(false to 25L, ChipText.countdown(0, 25 * 60))
        assertEquals(false to 1L, ChipText.countdown(0, 10))
        assertEquals(true to 2L, ChipText.countdown(0, 100 * 60))
    }

    @Test fun routes() {
        val g = LaContent.fromMap(content())!!
        assertEquals("/game/e1", LaRoutes.open(g))
        assertEquals("/meetups/e1", LaRoutes.open(g.copy(eventType = "meetup")))
        assertEquals("/check-in/e1", LaRoutes.checkIn(g))
        assertEquals(LaRoutes.stableNotificationId("s1"), LaRoutes.stableNotificationId("s1"))
        assertTrue(LaRoutes.stableNotificationId("s1") > 0)
    }

    @Test fun kan1024CheckinOpenDrivesTheAction() {
        fun at(now: Long, vararg e: Pair<String, Any?>) = LaContent.fromMap(content(*e))!!.offersCheckInAt(now)
        val running = arrayOf("state" to "started", "checkin_open" to true)
        assertTrue(at(2_100, *running))
        assertEquals(UiState.RUNNING, LaContent.fromMap(content(*running))!!.uiState)
        assertFalse(at(2_100, "state" to "started", "checkin_open" to false))
        assertFalse(at(1_900, "checkin_open" to false))
        assertFalse(at(2_100, *running, "role" to "organiser"))
        assertFalse(at(2_100, *running, "checked_in" to true))
        assertTrue(at(2_100, *running, "checkin_closes_at" to 2_200L))
        assertFalse(at(2_200, *running, "checkin_closes_at" to 2_200L))
        assertFalse(at(2_100, "state" to "ended", "checkin_open" to true))
        // Missing field: the old rule.
        assertTrue(at(2_100))
        assertFalse(at(2_100, "state" to "started"))
    }
}
