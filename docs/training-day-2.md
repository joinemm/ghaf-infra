<!--
SPDX-FileCopyrightText: 2026 TII (SSRC) and the Ghaf contributors
SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Day 2: Follow a Ghaf build from source commit to hardware-test results

**Instructor:** Joonas

**Date:** Tuesday, October 20, 2026

**Finnish time:** 09:00–11:00 and 12:00–14:00

**UAE time:** 10:00–12:00 and 13:00–15:00

This session follows an everyday Ghaf development build through Jenkins, remote
building, signing, publication, and hardware tests. A completed `ghaf-main` run on
ci-prod connects the architecture and pipeline code to the resulting image,
supply-chain evidence, and test results.

By the end of the session, participants should be able to independently trace a
run, identify which component owns each step, find the resulting image and
evidence, explain verification decisions, and investigate a failed test handoff.

## Before the session

- Complete the Day 1 environment and access setup.
- Check that you can browse Jenkins runs, console logs, and artifacts.
- Have the ghaf-infra checkout available for the code walkthrough and exercises.

## Morning: From source commit to hardware tests

| Time, FI | Activity | Learning outcome |
|---|---|---|
| 09:00–09:10 | A completed ghaf-main run: trigger, commit, target branches, artifacts, and downstream tests. | Identify precisely what was built and which run produced it. |
| 09:10–09:35 | Responsibilities of the controller, remote builder, signing service, registry, and test agent. | Explain where work happens and how artifacts move between components. |
| 09:35–10:00 | The laptop target's pipeline declaration, shared library, and corresponding Jenkins stages. | Find where target and test selection end and shared execution begins. |
| 10:00–10:10 | Break | |
| 10:10–10:40 | Remote build output → signing → OCI publication → ghaf-hw-test → collected results. | Follow one image into tests on two devices and find their results. |
| 10:40–11:00 | Exercise: reconstruct the run using Jenkins and the relevant source files, followed by a group review. | Independently navigate a run and locate supporting evidence. |

The main target is `packages.x86_64-linux.intel-laptop-debug`. Its
[ghaf-main declaration](../modules/jenkins/pipelines/ghaf-main.groovy) configures
`_relayboot_bat_` tests for the `debug` variants on both Lenovo X1 and Darter Pro.
The selected run provides the actual downstream job links and results.

### Code walkthrough

The walkthrough follows three parts of the pipeline:

1. **The job definition:** trigger, checkout, build and test targets, and the call to
   `create_pipeline`.
2. **The shared execution:** Source VSA, evaluation, remote build, provenance,
   signing, and publication.
3. **The test handoff:** the published image reference, device and test selection,
   downstream job links, and collected results.

The [shared execution code](../modules/jenkins/pipeline-library/vars/pipelineExecution.groovy)
shows the concrete build path: Jenkins selects a remote store for the target's
architecture, runs `nix build` there, copies the result back, and roots it as
`unsigned-output`.

A Nix builder and a Jenkins hardware-test agent have different roles. The builder
produces store outputs; the test agent retrieves a published image and operates
physical devices. The
[architecture document](architecture.md#cicd-pipeline-flow) provides the supporting
flow.

The [test handoff](../modules/jenkins/pipeline-library/vars/hwTestUtils.groovy)
passes the published OCI digest reference to `ghaf-hw-test`, together with the
concrete test target, device tag, and test set. One generic laptop image is tested
using the device-specific variants declared in the job.

### Exercise: Reconstruct a run

Using the selected Jenkins run and repository sources, record answers to these
questions. Include the log entry, file, or metadata field supporting each answer.

- Which Ghaf commit and target did this run build?
- Which ghaf-infra revision supplied its workflow?
- Which remote builder/store handled the target?
- Where are its image, manifest, provenance, and signatures?
- Which hardware-test jobs used this image, on which devices, and with what results?

For each device, trace the parent job to its downstream `ghaf-hw-test` run and
match `OCI_IMAGE_REF` to the published image digest. Distinguish a successful
build, successful artifact verification, and successful hardware tests.

The [pre-merge job](../modules/jenkins/pipelines/ghaf-pre-merge.groovy) uses the
same shared execution with `_relayboot_pre-merge_` tests. It builds GitHub's PR
merge commit and reports status to the PR head commit. This is a brief comparison
with the main-branch run used for the exercises.

## Afternoon: What the evidence establishes

| Time, FI | Activity | Learning outcome |
|---|---|---|
| 12:00–12:10 | SLSA: purpose, source and build tracks, and the role of provenance and verification. | Explain what SLSA addresses and what evidence supports a trust decision. |
| 12:10–12:15 | One Source VSA example and its verification result. | Identify the source commit, issuer, policy, and asserted source level. |
| 12:15–12:30 | Inspect build provenance and distinguish it from signatures and test results. | Connect the build record to the source, infrastructure revision, builder identity, and run. |
| 12:30–13:00 | Trace the downstream job's image reference, device selection, verification stages, and collected results. | Explain what the agent checks before flashing and how results affect the parent run. |
| 13:00–13:10 | Break | |
| 13:10–13:45 | Small-group investigation of failure scenarios, followed by a review of the logs and evidence. | Find the failed boundary and choose the next useful evidence. |
| 13:45–14:00 | Group recap and questions. | Explain the complete path using the original run. |

### What SLSA explains

**SLSA** stands for **Supply-chain Levels for Software Artifacts**, pronounced
"salsa". It provides requirements and evidence for increasing confidence in how
software is produced and handled. For example, a legitimate source commit can
still be built on an unexpected platform or replaced with a different binary
during distribution. SLSA addresses supply-chain integrity; functional tests and
vulnerability analysis answer different questions.
[SLSA introduction](https://slsa.dev/spec/v1.2/about).

SLSA separates source and build security into tracks:

| Track | Question | Connection to this session |
|---|---|---|
| Source | How was this source revision managed and created? | The Source VSA asserts a source level for a specific commit. |
| Build | How was the artifact built, and how trustworthy is that build process? | Build provenance describes the source, workflow, builder identity, and outputs. |

Source Level 1 concerns version-controlled source. Higher source levels add
history and provenance, enforced technical controls, and review requirements.
The repository's Source VSA implementation asserts `SLSA_SOURCE_LEVEL_1`; that
claim does not assign a build level.
[Source requirements](https://slsa.dev/spec/v1.2/source-requirements).

For reference, build levels describe progressively stronger guarantees:

| Build level | Main addition |
|---|---|
| L1 | Provenance records how the artifact was built. |
| L2 | A hosted build platform generates and authenticates the provenance; consumers verify it. |
| L3 | A hardened build platform protects against interference between builds and access to provenance-signing secrets by user-defined build steps. |

These are summaries of the [Build Track requirements](https://slsa.dev/spec/v1.2/build-track-basics).
Producing a signed provenance file alone does not establish that all requirements
of a build level are met. This session examines the implemented evidence and
checks rather than assigning a build level to Ghaf CI.

### Attestations, signatures, and verification

An attestation makes a claim about an identified subject, such as a source commit
or build output. [Build provenance](https://slsa.dev/spec/v1.2/provenance)
describes its origin; a
[Verification Summary Attestation (VSA)](https://slsa.dev/spec/v1.2/verification_summary)
records a verifier's decision against a policy.

In the JSON statement, `subject` identifies what the claim concerns and its
digest; `predicateType` identifies the kind of claim, and `predicate` contains
its details. The signed Source VSA and build provenance use different predicates
because they make different claims.

A signature authenticates the signed content against a key or identity. The
consumer also needs to establish that the evidence applies to the intended
artifact and meets its expectations for the signer, source, and build process.
Those are separate verification decisions.
[Artifact verification](https://slsa.dev/spec/v1.2/verifying-artifacts).

| Evidence | Question to ask |
|---|---|
| Source VSA | Which source commit was verified, by whom, against which policy? |
| Build provenance | What source and workflow produced this output, where, and in which run? |
| Image signature | Does this image verify with the expected signing key? |
| Hardware-test results | What ran on which device, against which image, and with what outcome? |

### Source VSA

The walkthrough uses one decoded Source VSA and its verification result to
identify the commit, verifier, policy, and asserted source level. The repository's
`source-vsa inspect` and `verify` commands support further exploration. The
[implementation](../pkgs/source-vsa/src/source_vsa.py) verifies those claims as
well as the Sigstore identity.

In `ghaf-main`, Source VSA retrieval and verification are requested but optional.
If unavailable or invalid, the stage is marked unstable and the build continues.
That behavior is explicit in
[pipeline execution](../modules/jenkins/pipeline-library/vars/pipelineExecution.groovy).
If the selected run has no bundle, a separately identified verified example can
illustrate the format; it does not establish a source claim for that run.

### Build provenance

Match these fields back to the morning's run:

- `externalParameters.target`: Ghaf repository, commit, and target.
- `externalParameters.workflow`: ghaf-infra repository and deployed revision.
- `runDetails.builder.id`: the CI identity.
- Invocation URL and build timestamps.
- The provenance subject and resolved dependencies.

The pipeline generates provenance from `unsigned-output` and separately signs
the provenance and image. The selected `ghaf-main` target does not request UEFI
signing. Its detached image signature and provenance signature support the
downstream verification steps.

### Verification and hardware-test results

The [hardware-test job](../modules/jenkins/pipelines/ghaf-hw-test.groovy) retrieves
provenance and its signature, applies the
[provenance trust policy](../slsa/provenance-trust-policy.yaml), downloads the
image, and verifies its detached signature before flashing. The policy checks
the expected provenance type, build type, source repository, permitted CI
identity, and a build finished less than six hours ago.

The parent pipeline collects downstream job links and results into
`test-results.json` and per-test artifact directories. Test results can also be
attached to the published image as OCI referrers. The image is published before
tests run, so its presence in the registry does not establish test success.
Follow both the parent and downstream results when investigating failures.

### Exercise: Investigate three scenarios

| Scenario | Expected investigation |
|---|---|
| The Source VSA stage is unstable, but the main build continues. | Check the commit and verification error, then find the pipeline's optional Source VSA behavior. |
| A provenance signature verifies, but the provenance policy rejects it. | Read the failed criterion: identity, target repository, build type, or freshness. Explain why signature verification alone is insufficient. |
| The image is published, but one hardware-test branch fails or has no published result. | Follow the downstream job, verification stages, test status, and result-collection log. |

Using the supplied logs and evidence, each group reports the failed stage or
missing evidence, the file or field that supports its diagnosis, and its next
action.

## Connection to the other sessions

Day 2 builds on Day 1's CI overview, Nix basics, repository structure, VM, and
checks. The exercises use completed builds and their evidence.

Day 3 examines SBOM contents and vulnerability scanning. Days 4 and 5 cover keys,
PKCS#11, Secure Boot, and hands-on signing. Day 6 covers test automation and the
hardware practical. This session establishes how those parts connect through the
pipeline and its artifacts.
