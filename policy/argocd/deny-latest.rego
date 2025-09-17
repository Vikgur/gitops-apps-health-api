package argocd

deny[msg] {
input.kind == "Application"
image := input.spec.source.helm.parameters[_]
image.name == "image.tag"
image.value == "latest"
msg := "Using 'latest' tag is not allowed"
}