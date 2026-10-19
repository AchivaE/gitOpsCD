# GitOps promotion

The common implementation is [validate-promotion.sh](validate-promotion.sh).
It accepts a service, environment, provider profile and verified OCI digest; it
updates only the image tag in the environment values file, lint/renders the
chart and emits a reviewable patch. It does not build, scan, sign, push, commit,
or create pull requests. It has no Azure DevOps, GitHub, registry, or Argo CD
API dependency.

[validate-argo-layout.sh](validate-argo-layout.sh) is the earlier, provider-neutral
Argo CD preflight. It verifies the Git-relative paths used by ApplicationSets,
the ESO bootstrap ordering, the AppProject destination for `external-secrets`,
and renders the exact active Helm value layers. It runs before every Azure
DevOps promotion and should run on every GitHub pull request.

```bash
bash pipelines/gitops/validate-promotion.sh \
  gateway-ingestor staging aws sha256:<64-lowercase-hex-characters>
```

## Platform adapters

- **Azure DevOps:** [promote-image.yml](promote-image.yml) is a thin adapter
  around the common script. It publishes the patch and can optionally create a
  reviewed Azure DevOps pull request. That optional step is the only
  Azure-DevOps-specific behavior.
- **GitHub:** the workflow template at `gitOpsCD/.github/workflows/gitops.yml`
  validates all local profiles on pull requests once copied to the Git root. Its
  manual workflow accepts the
  same four promotion inputs and publishes exactly the same patch artifact.

> The GitHub Actions file must live at
> `<repository-root>/.github/workflows/gitops.yml`. In this checkout, the Git
> root is the parent of `gitOpsCD`; GitHub will not discover a workflow kept
> under `gitOpsCD/.github`. The workflow content is already written for that
> root location and uses `gitOpsCD/...` paths.

For a production promotion, use a signed and security-scanned `sha256` digest.
The production Helm values reject a mutable tag; after a reviewed merge, Argo
CD observes the Git change and pulls the exact OCI image. Keep branch-protection
and approval rules in the selected Git platform; neither adapter bypasses them.
