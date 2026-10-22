# ADCM Kubernetes Sandbox & Log Rotation Sidecar

Экспериментальная песочница для развертывания **Arenadata Cluster Manager
(ADCM)** в локальном кластере Kubernetes (`minikube`) с использованием
декларативного Nix-окружения и паттернов надежного хранения состояния и
управления логами.

## 🎯 Цели проекта

1. **Воспроизводимая среда разработки:** Изоляция всех зависимости
   инструментария (`kubectl`, `minikube`, `helm`, `python`) через Nix Flakes &
   `direnv`.
2. **Изоляция состояния (State Management):** Разделение приложения и базы
   данных PostgreSQL с подключением надежных объемов через
   `PersistentVolumeClaim`.
3. **Паттерн Sidecar для логов:** Организация ротации и очистки текстовых логов
   ADCM в реальном времени через отдельный контейнер в пределах одного Pod'а без
   риска исчерпания дискового пространства.

---

## 🏗 Архитектура

Проект состоит из двух ключевых компонентов, изолированных в Kubernetes
Namespace `adcm-sandbox`:

```
+-------------------------------------------------------------------------+
| Namespace: adcm-sandbox                                                 |
|                                                                         |
|  +-----------------------+              +----------------------------+  |
|  | StatefulSet: postgres |              | Pod: adcm                  |  |
|  |                       |              |                            |  |
|  |  [postgres:16]        |              |  [adcm:2.11]               |  |
|  |         |             |              |        |                   |  |
|  +---------|-------------+              |   (/var/log/adcm)          |  |
|            |                            |        | (Shared Volume)   |  |
|      (PVC: pg-data)                     |        v                   |  |
|                                         |  [sidecar-log-rotator]     |  |
|                                         |                            |  |
|                                         +------------|---------------+  |
|                                                      |                  |
|                                                (PVC: adcm-data)         |
+-------------------------------------------------------------------------+
```

* **PostgreSQL StatefulSet:** Одиночная реплика базы данных с гарантированным
  PVC для хранения метаданных ADCM.
* **ADCM Pod (Multi-container):**
  * **Main Container:** Официальный образ ADCM
    (`hub.arenadata.io/adcm/adcm:2.11`).
  * **Sidecar Container:** Легковесный обработчик на базе `busybox`/`alpine`,
    отслеживающий заполнение логов и выполняющий их ротацию/очистку в общем
    volume.

---

## 🚀 Быстрый старт

### Предварительные требования

Для запуска требуется установленный [Nix](https://nixos.org/) с включенной
поддержкой Flakes и `direnv` (или Docker/Minikube на хост-системе).

### 1. Активация окружения

Окружение подготавливается автоматически при входе в директорию благодаря
`direnv`:

```bash
cd adcm-k8s-sandbox
direnv allow
```

*Или вручную через Nix:*

```bash
nix develop
```

### 2. Запуск песочницы

```bash
# 1. Запуск Minikube
minikube start

# 2. Создание Namespace
kubectl apply -f manifests/01-namespace.yaml

# 3. Развертывание базы данных PostgreSQL
kubectl apply -f manifests/02-postgres.yaml

# 4. Развертывание ADCM с Sidecar-ротатором
kubectl apply -f manifests/03-adcm-app.yaml
```

---

## 🧪 Проверка работы Sidecar и логов

Чтобы убедиться, что Sidecar корректно видит и обрабатывает логи ADCM:

```bash
# Просмотр логов Sidecar-контейнера
kubectl logs -n adcm-sandbox -l app=adcm -c log-rotator -f

# Проверка общего Volume внутри пода
kubectl exec -n adcm-sandbox -it deploy/adcm -c adcm-app -- ls -la /adcm/data/log
```

---

## 📝 Лицензия

MIT
