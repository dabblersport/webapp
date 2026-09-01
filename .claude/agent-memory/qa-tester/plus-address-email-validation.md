---
name: plus-address-email-validation
description: /email_input Continue button silently stays disabled for RFC-valid plus-addressed emails (name+tag@domain.com), no error shown
metadata:
  type: project
---

On canary.dabbler.pro's `/email_input` signup screen (2026-08-30), typing an
RFC-valid plus-addressed email (`moataz.mustapha+qaotp1@gmail.com`) left the
Continue button permanently disabled with no visible validation error. The
identical address without the `+tag` (`moataz.mustapha@gmail.com`) enabled the
button immediately. Confirmed by direct A/B typing in the same field, same
session.

**Why it matters:** plus-addressing is common for real users organizing inboxes
and is valid per RFC 5321/5322. If the client-side email regex excludes `+`,
it's rejecting valid signups silently (no error text — just an inert button,
which is exactly the "control is inert" failure class QA is told to watch for).

**Status:** flagged in a comment on KAN-89 (2026-08-30) rather than filed as its
own KAN ticket, since it surfaced mid-retest of a different ticket and is out of
that ticket's scope. Not yet triaged/ticketed by PO/backend-owner as of this
writing — check Jira before assuming it's still open.

**How to apply:** if a future QA pass touches the email/signup screens, verify
whether this has been ticketed and fixed; if not, this may warrant its own KAN
ticket (MEDIUM — secondary flow broken, no error shown, but there's a workaround
of using a plain address).
