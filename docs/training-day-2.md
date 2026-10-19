<!--
SPDX-FileCopyrightText: 2026 TII (SSRC) and the Ghaf contributors
SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Day 2: Follow a Ghaf installer from source commit to published artifact

**Instructor:** Joonas
**Date:** Tuesday, October 20, 2026
**Finnish time:** 09:00–11:00 and 12:00–14:00
**UAE time:** 10:00–12:00 and 13:00–15:00

Use one completed Jenkins run throughout, so architecture, pipeline code, and
supply-chain evidence connect to something concrete.

By the end of the session, participants should be able to independently trace a
run, identify which component owns each step, find the resulting image and
evidence, and explain why an artifact is accepted or rejected.

## Morning: How the pipeline produces an installer

| Time, FI | Activity | What participants should learn |
|---|---|---|
| 09:00–09:10 | Open a completed release-candidate run. Show its parameters, commit, target branches, and artifact link. | Identify precisely what was built and which run produced it. |
| 09:10–09:35 | Trace responsibility across the controller, remote builder, signing service, registry, and test agent. Add each component to a diagram as it appears in the run. | Explain where work happens and how artifacts move between components. |
| 09:35–10:00 | Follow the installer target from its pipeline declaration into the shared library. Match code to visible Jenkins stages. | Find where target selection ends and shared execution begins. |
| 10:00–10:10 | Break | |
| 10:10–10:40 | Trace the installer's files: remote build output → controller → signing → artifact manifest → OCI publication. | Locate the original output, published image, signatures, and metadata. |
| 10:40–11:00 | Participant exercise: reconstruct the run using Jenkins and the relevant source files. Review answers together. | Navigate a run without relying on the trainer's screen. |

Use `packages.x86_64-linux.intel-laptop-debug-installer` as the main target. Its
[release-candidate declaration](../modules/jenkins/pipelines/ghaf-release-candidate.groovy)
gives a small, readable entry point: the target name, `uefisigniso: true`,
`sbom: true`, and `testset: null`.

### Code walkthrough

Keep the walkthrough to three stops:

1. **The job definition:** parameters, checkout, target set, and the call to
   `create_pipeline`.
2. **The shared execution:** Source VSA, evaluation, remote build, provenance,
   signing, and publication.
3. **The artifact manifest:** the record connecting output files, evidence, and
   signing information.

The [shared execution code](../modules/jenkins/pipeline-library/vars/pipelineExecution.groovy)
shows the concrete build path: Jenkins selects a remote store for the target's
architecture, runs `nix build` there, copies the result back, and roots it as
`unsigned-output`.

For the architecture discussion, make participants distinguish a Nix builder from
a Jenkins hardware-test agent. The builder produces store outputs; the test agent
retrieves a published image and operates physical devices. The
[architecture document](architecture.md#cicd-pipeline-flow) provides the supporting
flow.

### Exercise: Reconstruct a run

Participants should find five answers:

- Which Ghaf commit and target did this run build?
- Which ghaf-infra revision supplied its workflow?
- Which remote builder/store handled the target?
- Where are its image, manifest, provenance, and signatures?
- Does this installer target configure hardware tests?

The last question matters: the release-candidate installer entry has no configured
hardware tests. Contrast it with the
[nightly installer entry](../modules/jenkins/pipelines/ghaf-nightly.groovy), which
configures Lenovo X1 tests, including Secure Boot tests. This gives a concrete
example of why participants must inspect the target configuration rather than
infer coverage from the pipeline name.

## Afternoon: What the evidence establishes

| Time, FI | Activity | What participants should learn |
|---|---|---|
| 12:00–12:15 | Introduce SLSA through the evidence from the morning's run. | Separate a source-policy verdict, a build record, a signature, and a release-policy verdict. |
| 12:15–12:40 | Inspect the Source VSA and its verification path. | Identify the source commit, issuer, policy, and asserted source level. |
| 12:40–13:00 | Inspect the build provenance. Match its fields to Jenkins and Git. | Connect the artifact's build record to the source, infrastructure revision, builder identity, and run. |
| 13:00–13:10 | Break | |
| 13:10–13:30 | Follow publication, downstream verification, release policy, and archival. | Explain how evidence is consumed and why publication alone does not establish release acceptance. |
| 13:30–13:50 | Small-group investigation of three failure scenarios. | Find the failed boundary and choose the next useful evidence. |
| 13:50–14:00 | Participant teach-back and questions. | Explain the complete path using the original run. |

### Evidence and SLSA

Use this comparison to introduce the evidence. SLSA's specifications distinguish
[build provenance](https://slsa.dev/spec/v1.2/provenance) from a
[verification summary](https://slsa.dev/spec/v1.2/verification_summary), which
records a verifier's policy decision.

| Evidence | Question to ask |
|---|---|
| Source VSA | Which source commit was verified, by whom, against which policy? |
| Build provenance | What source and workflow produced this output, where, and in which run? |
| Image signature | Does this image verify with the expected signing key? |
| Release-policy attestation | Which release criteria passed or failed for this published artifact? |

### Source VSA

Show a real bundle and use the repository's `source-vsa inspect` and `verify`
commands. Have participants locate the commit, `sourceRefs`, verifier identity,
policy URI/digest, and `verifiedLevels`. The
[implementation](../pkgs/source-vsa/src/source_vsa.py) verifies those claims as
well as the Sigstore identity.

Then show the operational consequence in Jenkins: release-candidate requires a
valid Source VSA; the shared pipeline's default permits continuing without one.
The distinction is explicit in
[pipeline execution](../modules/jenkins/pipeline-library/vars/pipelineExecution.groovy).
Keep the SLSA discussion tied to these actual claims and checks.

### Build provenance

Have participants match these fields back to the morning's run:

- `externalParameters.target`: Ghaf repository, commit, and target.
- `externalParameters.workflow`: ghaf-infra repository and deployed revision.
- `runDetails.builder.id`: the CI identity.
- Invocation URL and build timestamps.
- The provenance subject and resolved dependencies.

Explain carefully that the pipeline generates provenance from `unsigned-output`
before modifying the image for UEFI signing. Trace the final image's detached
signature separately; avoid presenting the provenance subject as the final signed
ISO's checksum. Both operations are visible in the shared execution code.

### Release acceptance and archival

Open the actual [release policy](../slsa/release-policy.yaml). Ask participants to
distinguish required criteria from informational ones. Currently, image signature,
provenance signature, provenance policy, release-builder identity, and SBOM
presence are required; the hardware-test criterion is not required. Leave SBOM
contents for Henri's session.

Finish the flow with
[`ghaf-release-publish`](../modules/jenkins/pipelines/ghaf-release-publish.groovy):
OTA pinning and archival. Explain the practical timing constraint from the
[artifact-storage documentation](architecture.md#release-artifact-storage): the
local candidate artifacts must still exist, including when archival uses OCI;
ci-release baseline reset discards them on reboot.

### Exercise: Investigate three scenarios

| Scenario | Expected investigation |
|---|---|
| Release-candidate stops at Source VSA. | Check the requested commit, bundle availability, issuer identity, source ref, and verification error. |
| A provenance signature verifies, but the provenance policy rejects it. | Read the failed criterion: identity, target repository, build type, or freshness. Explain why signature verification alone is insufficient. |
| An installer appears in the registry, but has no hardware-test result. | Inspect that target's configured tests and the release-policy criteria before drawing conclusions. |

Use prepared logs or copied evidence for these exercises. Each group reports the
failed stage or missing evidence, the file or field that supports its diagnosis,
and its next action.

## Instructor preparation

- Choose one completed release-candidate run and one nightly installer run before
  the session.
- Record their exact commits, run URLs, and OCI digests.
- Download the small evidence files and save the relevant logs so the exercises
  remain usable if Jenkins or the registry is unavailable.
- Use existing outputs for the teaching session; a full installer build would
  make the schedule depend on build time.

## Boundaries with the other sessions

Henri's Day 1 already covers the CI overview, Nix basics, repository structure,
VM, and checks. Start directly from a real run and revisit those concepts only as
needed. His Day 3 owns SBOM analysis and vulnerability scanning.

Day 2 signing coverage should establish where signing happens and what consumes
its results. Aleksandr can then take participants into keys, PKCS#11, Secure Boot,
and hands-on signing. Mariia owns the test implementation and hardware practical.
