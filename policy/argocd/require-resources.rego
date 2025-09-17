package argocd

deny[msg] {
input.kind == "Application"
not input.spec.source.helm.parameters[_].name == "resources.requests.cpu"
msg := "Missing 'resources.requests.cpu' in Helm values"
}