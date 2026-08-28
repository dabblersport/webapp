# Version Control Memory Index

- [Canary pipeline incident](canary-pipeline-incident.md) — every Canary preview build failed silently for months on missing SUPABASE_URL; Cloudflare Pages Preview env was empty
- [Subagent dispatch trap](subagent-dispatch-trap.md) — the Agent tool silently falls back to general-purpose on an unrecognised subagent_type; registry is scoped to the session's working directory
- [Deploy verification channels](deploy-verification-channels.md) — the Pages build verdict IS readable via `gh api .../check-runs`; WAF 403, empty deployments API and a blank first screenshot are false alarms
- [Record the fact, not a pointer](record-the-fact-not-a-pointer.md) — never write "see below" for an unestablished fact; state the unknown in the field and say what a missing follow-up means
- [Skills install writes three places](skills-install-three-locations.md) — .claude/skills/, .agents/skills/ and skills-lock.json; a brief naming only the first is always incomplete
- [Android signing secret still at HEAD](android-signing-secret-still-at-head.md) — SEC-11/KAN-57 is open; the fix is uncommitted, HEAD still has the plaintext password
