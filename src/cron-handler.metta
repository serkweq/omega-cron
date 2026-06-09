; cron-handler.metta
; External cron trigger pipeline for OmegaClaw.
; Parses cron: prefixed messages and dispatches to registered skill handlers.
;
; Message format: cron:<skill>:<task>[:<payload>]
;
; Security: skill whitelist enforced server-side in cron-helper.py.
; Unknown skills are rejected before any handler runs.
;
; Registered skills:
;   ping       — health check, returns CRON-OK + timestamp
;   test       — pipeline sanity check
;   instagram  — social media posting (weekly-post task)
;   summary    — daily briefing generation (daily-morning task)
;   backup     — memory snapshot (memory-snapshot task)
;   memory     — memory inspection / queries


; ─── Top-level entry ─────────────────────────────────────────────────────────
;
; The LLM receives a message, checks if it starts with "cron:",
; and calls (crontab $message). This is the only skill the LLM
; needs to know about — internal dispatch is fully deterministic.

(= (crontab $raw)
   (let $result (py-call (cron_helper.parse_cron_message $raw))
        (let $valid (py-call (cron_helper.get_field $result "valid"))
             (if (== $valid "False")
                 (let $error (py-call (cron_helper.get_field $result "error"))
                      (println! (CRON INVALID: $error))
                      (send (swrite "Cron dispatch failed: " $error)))
                 (let $skill (py-call (cron_helper.get_field $result "skill"))
                      (let $task  (py-call (cron_helper.get_field $result "task"))
                           (let $payload (py-call (cron_helper.get_field $result "payload"))
                                (println! (CRON DISPATCH: $skill $task $payload))
                                (crontab-dispatch $skill $task $payload))))))))


; ─── Whitelist-gated dispatch ────────────────────────────────────────────────
;
; Only explicitly registered skills can be triggered.
; To add a new skill: (1) add to WHITELIST in cron-helper.py
;                      (2) add a case here
;                      (3) implement the handler function below

(= (crontab-dispatch $skill $task $payload)
   (case $skill
     ((("ping"      (cron-ping $task $payload))
       ("test"      (cron-test $task $payload))
       ("instagram" (cron-instagram $task $payload))
       ("summary"   (cron-summary $task $payload))
       ("backup"    (cron-backup $task $payload))
       ("memory"    (cron-memory $task $payload))
       ($else       (send (swrite "Cron: no handler for skill '" $skill "'"))))))


; ─── Skill handlers ──────────────────────────────────────────────────────────

(= (cron-ping $task $payload)
   ; Minimal test: just send "moo" to the bound Telegram chat (group or DM)
   (send "moo")
   (println! (CRON-PING: moo)))


(= (cron-test $task $payload)
   (send "Cron test handler reached. System nominal."))


(= (cron-instagram $task $payload)
   (if (== $task "weekly-post")
       (let $post-text (cron-build-instagram-weekly $payload)
            (send $post-text)
            (println! (INSTAGRAM-POST: $post-text)))
       (send (swrite "Cron: unknown instagram task '" $task "' (known: weekly-post)"))))


(= (cron-summary $task $payload)
   (if (== $task "daily-morning")
       (progn (println! "Cron: daily morning summary triggered")
              (send "Morning summary triggered — agent will compile and send."))
       (send (swrite "Cron: unknown summary task '" $task "' (known: daily-morning)"))))


(= (cron-backup $task $payload)
   (if (== $task "memory-snapshot")
       (progn (println! "Cron: memory snapshot triggered")
              (send "Memory backup triggered."))
       (send (swrite "Cron: unknown backup task '" $task "' (known: memory-snapshot)"))))


(= (cron-memory $task $payload)
   (send "Cron memory handler placeholder."))


; ─── Content builders ────────────────────────────────────────────────────────
;
; Instagram weekly post text. Edit this to match Mind Children's voice.
; Payload (optional, after the third colon) is appended as a rider.

(= (cron-build-instagram-weekly $payload)
   (let $base "🌙 Mind Children optimizes for connection, not output."
        $tail (if (== $payload "")
                 ""
                 (swrite " // " $payload))
        (swrite $base $tail " #MindChildren #AI #HumanConnection")))