<!--
SPDX-FileCopyrightText: 2026 TII (SSRC) and the Ghaf contributors
SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Day 2: Instructor notes

Companion to the [participant page](training-day-2.md) for Joonas's session on
October 20, 2026. All times below are Finnish time.

## Main thread

Follow one completed `ghaf-main` run on ci-prod and its
`packages.x86_64-linux.intel-laptop-debug` target through the whole day. This
target configures `_relayboot_bat_` tests on Lenovo X1 and Darter Pro. Follow both
downstream jobs, including verification and collected results.

Opening line: "Today we will follow one main-branch build from its source commit
through publication and tests on two laptops, then examine the evidence checked
before those tests run."

Return to three questions whenever the discussion gets detailed:

- Which component performs this step?
- Which exact input or artifact does it act on?
- Where is the evidence of its result?

## Prepare before the session

The run-specific examples below still need to be selected. No completed run or
artifact has been retrieved as part of preparing these notes.

| Item | Record before the session |
|---|---|
| Main-branch run | Jenkins URL and build number |
| Build target | `packages.x86_64-linux.intel-laptop-debug` |
| Ghaf source | Full commit SHA resolved from the checkout of `main` |
| Infrastructure | ghaf-infra revision recorded in provenance |
| Published image | OCI repository, run-specific tag, and resolved digest |
| Saved artifacts | Artifact URL and saved target directory |
| Hardware tests | Lenovo X1 and Darter Pro downstream URLs, target variants, parameters, and results |
| Pre-merge comparison | Job definition; optionally one run showing merge SHA versus PR head SHA |

Choose a main run with successful image/provenance signing and completed hardware
tests on both devices. Prefer one that also fetched a valid Source VSA. If that
bundle is absent, prepare a separately identified example for the format walkthrough.
Check the saved files against the pipeline revision that produced them: today's
checkout can differ from a historical run.

Save the console log and these small files locally:

- `manifest.json` and `oci-result.json`.
- `attestations/source-vsa.sigstore.json`, when present; otherwise a clearly
  identified example from another commit.
- `attestations/provenance.json` and its `.sig` file.
- `test-results.json`, per-test `result.json` files, and the relevant downstream
  logs and copied test artifacts.

The [ghaf-fetch helper](../scripts/ghaf-fetch.sh) can select metadata and referrers
without selecting the large image. Work in an empty directory when downloading.
Keep the exact OCI digest for the exercise; an environment's `latest` tag can
move to a different run.

Open these browser tabs ahead of time:

1. The main run's overview, console log, artifacts, and downstream job links.
2. The [main job](../modules/jenkins/pipelines/ghaf-main.groovy).
3. The [shared execution](../modules/jenkins/pipeline-library/vars/pipelineExecution.groovy).
4. The [provenance trust policy](../slsa/provenance-trust-policy.yaml).
5. Both downstream hardware-test runs and their parameters and results.
6. The [pre-merge job](../modules/jenkins/pipelines/ghaf-pre-merge.groovy) for a
   brief comparison of checkout, test sets, and PR status reporting.

Rehearse the metadata commands below using the saved files. If live verification
is unavailable, show the saved verification log and distinguish it from a check
performed during the session. Use completed outputs for the walkthrough; no new
build, signing operation, deployment, or hardware flashing is needed.

## Morning delivery notes

### 09:00–09:10 — Establish the identity of the run

Start in Jenkins rather than on a repository overview slide. Point out the job,
build number, trigger, resolved source commit, target branches, artifact link,
and downstream jobs. The job checks out `main`; the resolved full commit
identifies the source actually used. This job does not ask the user for `GITREF`.

Ask: "If I send you only the job name and `main`, could you identify this exact
image later?" Expected answer: the run and resolved source/artifact identities
are needed to identify this instance.

### 09:10–09:35 — Assign responsibilities

Build the explanation around these roles:

| Component | Responsibility in this example |
|---|---|
| Jenkins controller | Checkout, evaluation, orchestration, provenance generation, signing commands, publication, downstream scheduling, and result collection |
| Remote Nix builder | Build the target and hold its resulting store output |
| Signing gateway/HSM | Service signing requests using the configured keys |
| OCI registry | Store published images and attached evidence |
| Hardware-test agent | Retrieve and verify the published image, operate a device, and return test results when configured |

Prod/dev use `hetz86-1` and `hetzarm`. The selected x86_64 target uses the
configured x86_64 remote store. Use the actual run's
`manifest.build.remote_store` to establish which store handled this target.
Sources: [prod configuration](../hosts/hetzci/prod/configuration.nix),
[shared builders](../hosts/hetzci/remote-builders.nix), and
[architecture](architecture.md#cicd-pipeline-flow).

Explain that `runDetails.builder.id` is set to the Jenkins URL. It does not name
the physical remote builder. Ask participants where they would find each identity.

Keep the overview short: Henri already covered the CI map and Nix fundamentals.
Show the cache's role if asked, then return to the selected artifact path.

### 09:35–10:00 — Connect job configuration to execution

In `ghaf-main.groovy`, show:

- The push trigger and checkout of `main`.
- The `intel-laptop-debug` entry and its two `tests` entries.
- The Lenovo X1 and Darter Pro `debug` variants and `_relayboot_bat_` test set.
- `pipelineExecution.create_pipeline(...)` and the parallel target branches.

Then move to `pipelineExecution.groovy`. Use stage names as search anchors instead
of reading the file from top to bottom. Show `Source VSA`, `Eval`, and the target's
`Build` stage. Each target's shared execution is what produces the repeated
branches participants see in Jenkins.

Explain that a configured signing request and a successful signing result are
different facts. The pipeline also checks whether signing is enabled, and records
the outcome in the manifest. For this target, image/provenance signatures are
part of the shared execution; no UEFI signing or SBOM generation is requested.

Spend at most five minutes comparing `ghaf-pre-merge`: it builds GitHub's merge
commit, uses `_relayboot_pre-merge_`, and posts status to the PR head SHA. The
resolved merge commit and the commit receiving the status are different
identities. Henri has already covered the pre-merge overview.

### 10:00–10:10 — Break

### 10:10–10:40 — Follow the actual files

Trace this sequence in the selected target's log and directory:

1. The controller chooses the target architecture's remote store from
   `/etc/jenkins/remote-stores.json`.
2. `nix build --store ... --eval-store auto --json --no-link` returns the remote
   output path.
3. `nix copy` brings that output to the controller; `unsigned-output` roots it.
4. Provenance is generated from `unsigned-output` and signed.
5. Image discovery finds the built disk image; a detached image signature is
   created. The pipeline links the image into `images/` and writes the manifest.
6. OCI publication records the image's digest reference in `oci-result.json`.
7. The parent triggers `ghaf-hw-test` for each configured device with that digest,
   a concrete test target, device tag, and test set.
8. The test agent verifies provenance and image signature before flashing and
   running the configured tests.
9. The parent collects downstream job links, statuses, and artifacts and publishes
   test-result referrers when that stage completes as expected.

Show the exact handoff in
[`hwTestUtils.run_hw_test`](../modules/jenkins/pipeline-library/vars/hwTestUtils.groovy):
`OCI_IMAGE_REF`, `TEST_TARGET`, `DEVICE_TAG`, and `TESTSET`. One generic image is
tested through two device-specific variants. Compare the downstream parameters
against the parent manifest and OCI result.

The provenance trust-policy check for this main run occurs in the hardware-test
job. The controller's pre-test provenance-policy stage is conditional on the
release environment, so it is not part of this example.

The pipeline's trusted-builder copy uses `--no-check-sigs`. Explain its scope if
asked: accepting store output from the trusted builder is separate from verifying
the published image's detached signature.

### 10:40–11:00 — Morning exercise and answer guidance

Allow about ten minutes for investigation and ten for reviewing evidence.

| Participant question | Evidence to accept |
|---|---|
| Which Ghaf commit and target? | Manifest `source.revision` and `target`; provenance `predicate.buildDefinition.externalParameters.target`; checkout log |
| Which ghaf-infra revision? | Provenance `predicate.buildDefinition.externalParameters.workflow.ref`; this is the controller's recorded configuration revision |
| Which remote builder/store? | Manifest `build.remote_store` and the build command/log; not provenance's Jenkins `builder.id` alone |
| Where are image and evidence files? | Paths in manifest `images` and `attestations`, plus the run's artifact directory and OCI result |
| Which tests used this image? | Both downstream job links, `OCI_IMAGE_REF`, device and concrete test target, `_relayboot_bat_`, and recorded status |

Ask participants to match the two downstream `OCI_IMAGE_REF` values to the same
published digest. Verify what actually ran from the results; configured coverage
alone does not prove a successful test.

Before lunch, ask someone to describe the path from builder output through the
registry to both test devices.

## Afternoon delivery notes

### 12:00–12:10 — Explain SLSA before opening the JSON

Keep this introduction to ten minutes. The participant page's level table and
specification links are reference material, not a separate lecture.

- **First three minutes:** expand SLSA and give one threat example: "The expected
  commit passed review, but someone replaces the uploaded image. What evidence
  would the test agent need to catch that?"
- **Next three minutes:** distinguish the source and build tracks, then connect
  them to Source VSA and build provenance. Mention that levels describe stronger
  guarantees; use the reference table if there is a question about a level.
- **Last four minutes:** distinguish the build record, the verifier's decision,
  the signature, and observed test results. Ask whether a valid signature from an
  unexpected builder is enough. The consumer must also accept the identity and
  claims. Then move to the actual evidence.

Keep the following details available for questions:

Use the official [verification guidance](https://slsa.dev/spec/v1.2/verifying-artifacts)
for the general model, then distinguish the actual Ghaf checks shown in the code.
Do not claim that the provenance policy alone performs every step in that model.
It checks the signature and selected fields; image signature verification is a
separate operation in the downstream job.

The local Source VSA implementation asserts `SLSA_SOURCE_LEVEL_1`. Explain that
Source L1 concerns version-controlled source, not mandatory two-party review or
proof that all CI checks passed. A source level does not assign a build level.
Functional correctness and vulnerability analysis remain separate concerns.

### 12:10–12:15 — Show one Source VSA example

Show one decoded statement and its prepared verification result. Point out the
commit, verifier, policy, and source level. `source-vsa inspect` decodes the
statement; `verify` checks it. Finish with the optional-stage behavior in
`ghaf-main`, then move on. Keep the implementation and command details for
questions or later reference.

For reference, in the [implementation](../pkgs/source-vsa/src/source_vsa.py), the verification
path checks the expected repository and commit, allows `refs/heads/main`, checks
the signed statement's claims, and verifies the Sigstore certificate identity
for the expected GitHub workflow, repository, ref, SHA, issuer, and push trigger.

Do not describe this VSA as proof that all CI jobs passed or that the code is
vulnerability-free. Explain the specific claims the issuer makes and the consumer
checks. In `ghaf-main`, the optional path records an unstable Source VSA stage
and continues the build. If that happened in the selected run, show the error and
the optional-stage code. A separate bundle can illustrate the format, but its
commit must stay clearly separate from the main example's identity.

### 12:15–12:30 — Read provenance as a build record

Start with the fields participants already know: target commit, target name,
ghaf-infra revision, Jenkins URL, invocation link, and timestamps. Then expand the
subject and resolved dependencies just enough to explain what they identify.

Use the current code constructing `PROVENANCE_EXTERNAL_PARAMS` as the field map.
The [build-type document](../slsa/v1.0/L1/buildtype.md) contains historical example
repository names and URLs; use the selected run's values in the demonstration.

Two distinctions to repeat:

- A valid signature does not establish that the signer, source, or build type is
  allowed by the consumer's policy.
- The provenance subject, a file checksum, and the OCI manifest digest identify
  different things. Read what each digest covers before comparing values.

### 12:30–13:00 — Follow verification and the test handoff

Spend roughly ten minutes matching the image digest, test target, device tag,
and test set between the parent and downstream jobs. Use another ten minutes
for verification and ten for following results back to the parent.

In [ghaf-hw-test](../modules/jenkins/pipelines/ghaf-hw-test.groovy), stop at
`Verify provenance`, `Image download`, and the image signature check before
`Flash`. Then follow the configured `Relay Boot test` and `Bat test` results back
to the parent run. Explain job orchestration and results; leave Robot test
implementation, relays, and hardware operation for Mariia.

The [provenance trust policy](../slsa/provenance-trust-policy.yaml) requires the
expected predicate/build type, target repository, permitted CI identity, and a
build finished less than six hours ago, with signature verification enabled.

An old saved run will fail a fresh evaluation of the time criterion. Show its
recorded verdict for the historical result. If rerunning the policy, explain the
expected freshness failure; do not edit the signed metadata to make it pass.

Show the collected entries in `test-results.json` and each test's `result.json`
and copied artifacts. A downstream non-success status causes the parent result
to be marked failed during collection. Exceptions during test execution are also
recorded and propagated after collection.

An image can exist in the registry even when a later test fails. Completed test
branches can publish failure results; an exception that prevents completion can
cause OCI test-result publication to be skipped. Read the collection/publish log
and saved results before concluding that missing referrers mean no tests ran.

Keep release policy and archival outside the main walkthrough. If asked, point to
the [release-policy documentation](architecture.md#release-artifact-storage) as a
separate consumer of evidence.

### 13:00–13:10 — Break

### 13:10–13:45 — Investigation exercise: answer guidance

Use supplied logs with known causes. If a real failure example is unavailable,
present the scenario as a hypothetical and ask for an investigation path rather
than claiming a particular failure occurred.

| Scenario | Expected reasoning and next action |
|---|---|
| Source VSA is unstable but the main build continues | Confirm the resolved commit, then read the fetch/verification error. Distinguish absent evidence, retrieval failure, and rejected claims or identity. Find the optional Source VSA path in shared execution; the unstable stage does not itself fail this main build. |
| Signature passes, provenance policy fails | Identify the failing criterion. For an old fixture, the six-hour freshness rule explains the rejection. For identity/repository/build-type failures, compare the exact recorded value with the policy. Signature validity alone does not satisfy policy. |
| Image is published but a hardware-test branch fails or has no published result | Match the OCI digest to the downstream parameters, identify the failed stage and device, and read verification/test logs. Check parent collection and publication logs. Distinguish a failed check, test failure, queue/agent problem, and missing result publication. |

Use the optional Source VSA case as a short warm-up, then spend most of the
exercise on the policy rejection and downstream test failure. Allow roughly
twenty minutes for investigation, ten for reviewing evidence and next actions,
and five for follow-up questions.

### 13:45–14:00 — Close with a participant explanation

Ask one participant to trace the original build and another to describe the
verification decisions. Use these prompts if needed:

- Where did the image get built, and where did signing happen?
- How do you identify the exact source and infrastructure revisions?
- Which checks ran before the agent flashed the image?
- How would you establish whether this exact image passed tests on both devices?

Hand off SBOM contents and vulnerability scanning to Henri, signing operations to
Aleksandr, and test implementation and hardware validation to Mariia.

## Commands for the saved evidence

Run from the ghaf-infra checkout inside `nix develop`. Set `training_target_dir`
to the saved target directory containing `manifest.json` and `attestations/`.
These commands inspect files and verify the existing VSA; they do not issue one.

```bash
training_target_dir=/absolute/path/to/saved/target

# Source, target, build location, and recorded artifact paths.
jq '{job, source, target, build, images, uefi, attestations}' \
  "$training_target_dir/manifest.json"

# The provenance fields used in the walkthrough.
jq '{
  subject,
  buildDefinition: .predicate.buildDefinition,
  runDetails: .predicate.runDetails
}' "$training_target_dir/attestations/provenance.json"

# Collected downstream test identities, job links, statuses, and artifact paths.
jq . "$training_target_dir/test-results.json"

# Published digest reference passed to both downstream jobs.
jq '.primary' "$training_target_dir/oci-result.json"

# Decode the Source VSA statement without verifying it.
nix run .#source-vsa -- inspect \
  --bundle "$training_target_dir/attestations/source-vsa.sigstore.json"

# Verify against the expected source commit recorded for this target.
training_commit=$(jq -r '.source.revision' "$training_target_dir/manifest.json")
nix run .#source-vsa -- verify \
  --repository tiiuae/ghaf \
  --commit "$training_commit" \
  --bundle "$training_target_dir/attestations/source-vsa.sigstore.json"
```

Run the Source VSA commands only when that run supplied a bundle. If demonstrating
a separately prepared example, use its own expected commit and bundle path.
Confirm the expected commit independently from the selected run before verifying.
The manifest is a convenient source for the command argument, not an independent
trust anchor. Public-key verification of image/provenance signatures also needs
the certificate configuration expected by
[`verify-signature`](../scripts/verify-signature.sh); rehearse in that environment
or use the saved verification logs.

## If time or connectivity runs short

- Keep the breaks and both exercises. Reduce source browsing to the laptop target
  declaration, the shared build/sign/publish stages, the downstream handoff, and
  the provenance policy. Retain the SLSA introduction before inspecting evidence.
- Skip the full resolved-dependency list and the optional pre-merge comparison.
- If Jenkins or registry access fails, use the saved run log and metadata. Keep
  the same artifact identity throughout.
- Record detailed Nix, HSM, SBOM, and Robot questions for the corresponding
  sessions so the artifact and evidence thread stays clear.
