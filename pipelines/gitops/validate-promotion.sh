#!/usr/bin/env bash
# Provider-neutral GitOps promotion validation. It deliberately does not build,
# scan, sign, push, commit, or create pull requests.
set -euo pipefail

service="${1:?usage: validate-promotion.sh <service> <environment> <provider> <sha256-digest>}"
environment="${2:?usage: validate-promotion.sh <service> <environment> <provider> <sha256-digest>}"
provider="${3:?usage: validate-promotion.sh <service> <environment> <provider> <sha256-digest>}"
digest="${4:?usage: validate-promotion.sh <service> <environment> <provider> <sha256-digest>}"
patch_out="${PATCH_OUT:-image-promotion.patch}"
script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
delivery_root="$(CDPATH= cd -- "${script_dir}/../.." && pwd)"
repository_root="$(git -C "${delivery_root}" rev-parse --show-toplevel)"

case "$service" in config-ingestor|gateway-ingestor) ;; *) echo "unsupported service: $service" >&2; exit 2 ;; esac
case "$environment" in dev|staging|prod) ;; *) echo "unsupported environment: $environment" >&2; exit 2 ;; esac
case "$provider" in local|azure|aws) ;; *) echo "unsupported provider profile: $provider" >&2; exit 2 ;; esac
if ! [[ "$digest" =~ ^sha256:[a-f0-9]{64}$ ]]; then
  echo "digest must be a lowercase OCI sha256 digest" >&2
  exit 2
fi

chart_path="${delivery_root}/argoCD/helm/services/${service}"
values_file="${chart_path}/values-${environment}.yaml"
provider_values_file="${chart_path}/values-${provider}.yaml"

for required_file in "$chart_path/Chart.yaml" "$values_file" "$provider_values_file"; do
  test -f "$required_file" || { echo "missing required file: $required_file" >&2; exit 2; }
done

# The promoted digest is the only tracked value deliberately changed by this
# command. A platform adapter may review, commit, or publish the resulting patch.
sed -i -E "s|^  tag: .*|  tag: ${digest}|" "$values_file"

git -C "${repository_root}" diff --check
helm lint "$chart_path" -f "$provider_values_file" -f "$values_file"
helm template "$service" "$chart_path" \
  --namespace "spaceup-${environment}" \
  -f "$provider_values_file" \
  -f "$values_file" > rendered.yaml
grep -Fq "@${digest}" rendered.yaml
git -C "${repository_root}" diff -- "${values_file#"${repository_root}"/}" > "$patch_out"

echo "Validated ${service}/${environment} for ${provider}; patch: ${patch_out}"
