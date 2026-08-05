# TestFlight self-trial plan

- **Status:** Active
- **Last updated:** 2026-08-05
- **Trial owner and tester:** Project owner
- **Trial device:** Primary physical trial device
- **Repository baseline:** `0645be8` (`Initial Fieldnotes project`)

## Outcome

Distribute a dependable internal TestFlight build to the project owner and use it in daily life long enough to evaluate capture reliability, retrieval, performance, dictation, photo handling, and whether Fieldnotes helps surface small moments that carry meaning.

## Product north star

Fieldnotes should help people live first, capture lightly, and later excavate their lives for the small moments that matter.

The interface should get out of the way. Distinctiveness should come from restraint: purposeful motion, original artwork used sparingly, a calm capture flow, and reflection that reveals without judging or manufacturing significance.

## Signature first experiences

The first trial includes two deliberately crafted, one-time moments:

1. **First launch:** an inviting reveal, a concise product and privacy introduction, optional permission preparation, and a direct transition into capture. Every permission can be skipped. System prompts appear only after the user explicitly chooses to enable a capability.
2. **First successful Fieldnote:** a meaningful acknowledgment shown only after persistence succeeds. It should suggest that the moment has been safely placed somewhere the user can revisit. Later saves receive a quieter acknowledgment.

Both experiences must support VoiceOver, Dynamic Type, Reduce Motion, interruption, and relaunch.

## Workstreams and GitHub tracking

GitHub issue state is authoritative. The order below expresses dependencies, not a requirement that design exploration stop while reliability work proceeds.

### 1. Release foundations

- [Epic #13: Release foundations and distribution readiness](https://github.com/schalkneethling/fieldnotes/issues/13)
- Confirm the supported iOS floor, add production assets, and prove the signed archive path.

### 2. Data durability and recovery

- [Epic #14: Quality, persistence, and device verification](https://github.com/schalkneethling/fieldnotes/issues/14)
- [#21: Define and verify the Fieldnotes data-durability contract](https://github.com/schalkneethling/fieldnotes/issues/21)
- [#5: Recoverable persistent-store startup handling](https://github.com/schalkneethling/fieldnotes/issues/5)
- [#7: Resize and normalize stored photos](https://github.com/schalkneethling/fieldnotes/issues/7)
- [#6: Fieldnote deletion with confirmation](https://github.com/schalkneethling/fieldnotes/issues/6)

The active guarantees, failure semantics, and verification matrix are defined in the [data-durability contract](data-durability-contract.md).

Reliability comes before a polished success animation: the app must never imply that a Fieldnote is safe until its text and media are durably persisted.

### 3. Comprehensive confidence and performance

- [#11: Critical-flow and persistence test coverage](https://github.com/schalkneethling/fieldnotes/issues/11)
- [#12: Physical-device permission and persistence matrix](https://github.com/schalkneethling/fieldnotes/issues/12)
- [#20: Performance budgets and physical-device benchmarks](https://github.com/schalkneethling/fieldnotes/issues/20)

Coverage includes unit, SwiftData integration, migration, UI, failure-path, regression, and performance testing. Device baselines cover launch, capture readiness, text and photo saves, image processing, memory, dictation, retrieval, scrolling, relaunch, and TestFlight updates. Representative collections contain 100, 1,000, and 5,000 Fieldnotes.

### 4. First experience and product character

- [Epic #17: First experience and signature moments](https://github.com/schalkneethling/fieldnotes/issues/17)
- [#18: First-launch onboarding](https://github.com/schalkneethling/fieldnotes/issues/18)
- [#19: First successful Fieldnote moment](https://github.com/schalkneethling/fieldnotes/issues/19)
- [#8: Production app icon and color assets](https://github.com/schalkneethling/fieldnotes/issues/8)
- [#2: Accessibility and adaptive-layout audit](https://github.com/schalkneethling/fieldnotes/issues/2)

Design exploration should begin with an experience brief and motion or artwork prototypes. Implementation must use real persistence and permission states rather than simulated success.

### 5. Distribution and self-trial

- [Epic #16: TestFlight operations and internal trial](https://github.com/schalkneethling/fieldnotes/issues/16)
- Prepare App Store Connect, adopt a repeatable release workflow, distribute the build, and record daily-use feedback.

## Trial release gates

The self-trial build is ready when:

- The data-durability contract and its explicit limitations are documented.
- Critical capture, save, retrieval, deletion, relaunch, migration, and recovery behavior passes automated coverage.
- Text and media persistence pass the physical-device matrix on the primary trial device.
- Performance budgets are recorded and pass on the primary trial device with representative data volumes.
- First launch and first successful capture work across permission and accessibility states.
- Production icon and color assets are present.
- A signed Release archive passes Xcode Organizer validation.
- App Store Connect metadata, privacy declarations, support information, and “What to Test” notes are complete.
- The exact build commit and unique build number are recorded.

## Trial protocol

Use the TestFlight build as the ordinary capture tool for one week. Exercise typing, dictation, camera capture, photo selection, permission denial and later enablement, force-quit and relaunch, review ranges, deletion, and application upgrades.

Record crashes, content loss, failed or ambiguous saves, slow interactions, excessive storage or memory, confusing permission behavior, distracting motion, and whether review reveals genuinely useful moments. File actionable findings as GitHub issues and link them from the trial issue.

## Known boundaries and open questions

- iOS 26.0 is the accepted self-trial floor. The eventual public minimum remains a separate compatibility decision.
- Local persistence cannot protect against device loss or app deletion. The required export, backup, and restoration boundary is an open durability decision tracked in issue #21.
- Accounts, cross-device sync, analytics, advertising, broad localization, and public App Store release remain outside this self-trial unless a recorded decision changes scope.

## Recovered history

The initial readiness work was completed in an earlier Codex task. It created commit `0645be8`, added the README and readiness document, pushed `main`, and created GitHub issues #1–#16. This plan and the decision log are the durable continuation of that work.
