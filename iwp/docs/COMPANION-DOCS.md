# Companion document status

The build guide (P0.1) expects six companion documents in `docs/`. Two were supplied
to this build. The rest are recorded here as missing so that no task silently invents
their contents.

| Document | Status | Tasks that depend on it |
|---|---|---|
| PRD v2.0 | **Present** — `docs/immigrant-wealth-protection-PRD-v2.md` | all |
| Build guide | **Present** — `docs/build-guide.md` | all |
| Architecture brief | Missing | P0.3 (the four priorities are quoted from the build guide instead) |
| Partner evaluation matrix | Missing | P6 (blocked on partner selection anyway) |
| Design system (`docs/design-system.md`, `design-system-visual.html`) | Missing | **P5.2 — blocked.** Also the §6.2 banned-word list used by P7.2 |
| Behavioral research | Missing | copy tone review |
| Readiness checklist | Missing | P8 |

## Consequences recorded, not worked around

- **P5.2 (core sender screens) is not built.** It is specified as "build against the
  design system", and the design system is not available. Building screens against an
  invented visual language would have to be thrown away.
- **P7.2 banned-word list** is seeded from the words named explicitly in PRD Feature 9
  (`compliance`, `KYC`, `AML`, `regulatory`) plus a conservative extension in
  `src/iwp/ai/banned_words.py`. The design system §6.2 list must be merged in before the
  eval gate can be considered complete. The merge point is a single module-level constant.
