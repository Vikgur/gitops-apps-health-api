# Оглавление

- [О проекте](#о-проекте)
- [Архитектура](#архитектура)
- [Логика](#логика)
- [Применение](#применение)
  - [Через Ansible (основной способ)](#через-ansible-основной-способ)
  - [Ручной способ для отладки и локального запуска без-ansible](#ручной-способ-для-отладки-и-локального-запуска-без-ansible)
- [Внедренные DevSecOps практики](#внедренные-devsecops-практики)
  - [Безопасность, linting и валидация](#безопасность-linting-и-валидация)
    - [.yamllint.yml](#yamllintyml)
    - [policy/argocd/*.rego](#policyargocdrego)
    - [.gitleaks.toml](#gitleakstoml)
    - [.pre-commit-config.yaml](#pre-commit-configyaml)

---

# О проекте

Этот проект — GitOps-репозиторий с Argo CD-приложениями (`Application`) для сервиса [`health-api`](https://github.com/vikgur/health-api-for-microservice-stack).

Управляются два окружения:
- **stage** — авто-синхронизация для обкатки продовых конфигураций.
- **prod** — ручной sync или через gate (e2e/CI/CD).

Репозиторий не содержит сам сервис, а только декларативные инструкции для Argo CD, откуда и как его развёртывать.  
Манифесты изолированы по окружениям (`apps/stage`, `apps/prod`), масштабируемы через `ApplicationSet`.

Внедрены [DevSecOps-практики](#внедренные-devsecops-практики): yamllint, kubeconform, gitleaks, OPA (Rego).

> Репозиторий — часть боевой инфраструктуры и управляется исключительно через Git и Argo CD.

---

# Архитектура 

- `apps/stage/health-api.yaml` — Argo CD Application для stage
- `apps/prod/health-api.yaml` — Argo CD Application для prod
- `applicationset.yaml` — шаблонный генератор (опционально)
- `kustomization.yaml` — точка входа Argo CD
- `overlays/stage/kustomization.yaml` — оверлей для stage
- `overlays/prod/kustomization.yaml` — оверлей для prod
- `.pre-commit-config.yaml` — yamllint, kubeconform, gitleaks, prettier
- `.gitignore` — исключает vault, retry-файлы и артефакты

---

# Логика
- `stage` — auto-sync, полноценная обкатка с продовыми values
- `prod` — ручной sync или через e2e-gate
- `kustomization.yaml` подключает оба окружения для Argo CD

---

# Применение

## Через Ansible (основной способ)

```bash
ansible-playbook -i inventories/stage playbook.yaml -e env=stage
ansible-playbook -i inventories/prod playbook.yaml -e env=prod
```

Плейбук из [`ansible-gitops-bootstrap-health-api`](https://github.com/vikgur/ansible-gitops-bootstrap-health-api) автоматически применяет все манифесты этого репозитория. 
Используется роль `argocd-apps`, которая настраивает Argo CD-приложения для `stage` и `prod`.

> Роли идут с идемпотентной логикой: безопасно запускать повторно, без разрушения состояния.

---

## Ручной способ для отладки и локального запуска без Ansible

**Прямое применение `Application`-манифестов:**

```bash
kubectl apply -f apps/stage/health-api.yaml -n argocd
kubectl apply -f apps/prod/health-api.yaml -n argocd
```

**Через `kustomize` (если нужно собрать всё сразу, например для локального `kind`/`minikube`):**

Применить всё:
```bash
kustomize build . | kubectl apply -f -
```

Только stage:
```bash
kustomize build overlays/stage | kubectl apply -f -
```

Только prod:
```bash
kustomize build overlays/prod | kubectl apply -f -
```

---

# Внедренные DevSecOps практики

В этот репозиторий внедрён набор DevSecOps-инструментов, обеспечивающих контроль качества и безопасности GitOps-манифестов.

Так как репозиторий содержит только CRD-манифесты Argo CD (`Application`), были выбраны валидаторы и политики, которые актуальны для этой структуры (например `checkov` не используется, чтобы избежать ложных срабатываний)

## Безопасность, linting и валидация

### `.yamllint.yml`

**Назначение:**  
Проверка синтаксиса и стиля YAML-файлов.  
Предотвращает ошибки форматирования и обеспечивает единый стандарт оформления.

---

### `policy/argocd/*.rego`

**Назначение:**  
OPA-политики для Argo CD `Application`.  
Запрещают:
- использование `tag: latest`,
- отсутствие `resources.requests.cpu`,
- другие потенциально опасные шаблоны в `Application`.

---

### `.gitleaks.toml`

**Назначение:**  
Поиск секретов в коммитах и файлах.  
Предотвращает утечку токенов, паролей и других чувствительных данных в Git.

---

### `.pre-commit-config.yaml`

**Назначение:**  
Автоматический запуск проверок перед коммитом (`yamllint`, `kubeconform`, `gitleaks`, `opa`).  
Позволяет выявлять проблемы ещё до попадания изменений в репозиторий.

---

> В результате обеспечивается базовое покрытие DevSecOps: от синтаксиса и валидации YAML до поиска утечек и политики безопасности на уровне Argo CD.