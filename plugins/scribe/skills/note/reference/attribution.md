# Speaker Attribution

Three passes to map diarized `SPEAKER_N` labels to people. Apply in order; each pass only looks at speakers unresolved by the prior pass.

## Pass A — Voice enrollment

```bash
scribe voices match --session "$SESSION" > /tmp/scribe-matches.json
```

Output shape:

```json
{
  "matches": [
    {
      "speaker_label": "SPEAKER_00",
      "enrolled_name": "Alice Chen",
      "similarity": 0.82
    }
  ]
}
```

Record `speaker_label → enrolled_name` for every match with `similarity >= ${user_config.voice_similarity_threshold}` (default 0.75). Speakers below the threshold carry forward unattributed.

## Pass B — LLM-inferred from calendar

For each speaker not attributed in Pass A:

1. Collect their `sample_utterances` from `artifact.speakers[]` (daemon already picks 3–5 per speaker).
2. Build the candidate list:
   - If `CandidateAttendees` (from the calendar step) is non-empty, use those names + roles.
   - Else fall back to all vault persons via `ls ${user_config.vault_path}/people/*.md` and read each `title:`.
3. Batch one prompt for all unresolved speakers (using your own LLM capability — not a subprocess). Include:
   - Each unattributed speaker with their utterances
   - The candidate list
   - Heuristics: `"thanks X"` implies the next speaker ≠ X; references to past PRs/work can hint at authorship

Expected JSON response:

```json
[
  {
    "speaker_label": "SPEAKER_01",
    "guess": "Alice Chen",
    "confidence": "high",
    "reasoning": "said 'I'll ship the PR' matching recent commits attributed to Alice"
  },
  {
    "speaker_label": "SPEAKER_02",
    "guess": null,
    "confidence": "low",
    "reasoning": "no distinctive cues"
  }
]
```

Accept only `confidence: high`. Pass medium/low through to Pass C.

## Pass C — Interactive fallback

For each still-unattributed speaker:

1. Prompt the user:

   ```
   Speaker <N> said:
     "<sample 1>"
     "<sample 2>"
     "<sample 3>"

   Who is this?
     1. <candidate 1 from calendar>
     ...
     N. Someone else (type a name)
     N+1. Unknown
   ```

   Candidates are `CandidateAttendees` minus anyone already attributed in Passes A/B.

2. Act on the response:
   - **Numbered candidate** → record the mapping. If the candidate has `person_path: null`, create the stub inline (template in [stubs.md](stubs.md)).
   - **Someone else** → prompt for a name; check for an existing slug; mark for stub creation if missing.
   - **Unknown** → label stays `Unknown Speaker <N>` throughout the note. No stub. No voice-save offer.

3. After each non-Unknown attribution, offer:

   > Save Speaker <N>'s voice as **<name>**? Lets Pass A auto-attribute next time. [y/N]

   On `y`:

   ```bash
   scribe voices confirm-from-session --session "$SESSION" --speaker "<label>" --name "<name>"
   ```

   Log the enrolled name for the final report.
