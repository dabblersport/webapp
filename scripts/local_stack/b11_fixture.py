# KAN-791: copy of the KAN-789 local helper (/Users/moataz/.claude/jobs/dcb6a775/tmp/b11_fixture.py), unchanged.
# Emits the B11 pre-image fixture: the four msg_* functions verbatim from their latest TRACKED migration
# (the files B11's own header names), plus the REVOKE/GRANT lines that follow each. Local chain only.
import re, sys
mig = sys.argv[1]
src = [("msg_evaluate", "20261017130000_kan558_msg_meetup_chat.sql"),
       ("msg_authorize", "20261017130000_kan558_msg_meetup_chat.sql"),
       ("msg_my_conversations", "20261017140000_kan559_msg_my_conversations_meetup_id.sql"),
       ("msg_game_conversation", "20261017120000_kan563_msg_game_conversation.sql")]
out = ["SET check_function_bodies = off;"]
for name, f in src:
    t = open(f"{mig}/{f}").read()
    i = t.index(f"CREATE OR REPLACE FUNCTION public.{name}(")
    m = re.compile(r"AS\s+(\$[A-Za-z_]*\$)").search(t, i)
    tag = m.group(1)
    j = t.index(tag, m.end()) + len(tag)
    j = t.index(";", j) + 1
    out.append(f"-- {name} verbatim from supabase/migrations/{f}")
    out.append(t[i:j])
    for line in t[j:].splitlines():
        if re.match(rf"\s*(REVOKE|GRANT) .*FUNCTION public\.{name}\(", line):
            out.append(line)
        elif line.strip().upper().startswith("CREATE"):
            break
print("\n".join(out))
