# 🛡️ Proxmox Homelab IaC

Terraform + Ansible для домашней инфраструктуры на Proxmox:

- **AdGuard Home** в LXC-контейнере на **двух** нодах (`envs/pve`, `envs/pve-2`);
- **k3s-кластер** (1 мастер + 2 воркера) на ноде `pve` (`envs/pve-k3s`) — см. раздел [☸️ k3s-кластер](#️-k3s-кластер).

AdGuard: автоматизированное развёртывание в LXC-контейнере на двух Proxmox-нодах. Обе ноды описываются одним модулем и одной ролью Ansible; различаются только данными (клиенты, IP, секреты) в своих `terraform.tfvars`.

## 🌐 Топология

Две площадки, соединённые site-to-site **IPSec-туннелем**:

```
   Квартира 1 (дом)                        Квартира 2
   LAN 192.168.1.0/24                       LAN 192.168.2.0/24
 ┌───────────────────────┐   IPSec    ┌───────────────────────┐
 │ Proxmox "pve"         │◀──────────▶│ Proxmox "pve-2"       │
 │  192.168.1.10         │  туннель   │  192.168.2.10         │
 │                       │            │                       │
 │  LXC adguard-home     │            │  LXC adguard-home     │
 │  192.168.1.2 (DNS)    │            │  192.168.2.2 (DNS)    │
 └───────────────────────┘            └───────────────────────┘
```

| Параметр            | `pve` (дом)        | `pve-2` (вторая квартира) |
| ------------------- | ------------------ | ------------------------- |
| Proxmox endpoint    | `192.168.1.10:8006`| `192.168.2.10:8006`       |
| Подсеть             | `192.168.1.0/24`   | `192.168.2.0/24`          |
| IP контейнера AGH   | `192.168.1.2`      | `192.168.2.2`             |
| Gateway             | `192.168.1.1`      | `192.168.2.1`             |
| VMID контейнера     | `100`              | `100`                     |
| Веб-панель          | `http://192.168.1.2` | `http://192.168.2.2`    |

## 📁 Структура репозитория

```
proxmox/
├── ansible/                       # ЕДИНАЯ роль настройки AdGuard (общая для всех нод)
│   ├── playbook.yml
│   ├── roles/adguard/
│   │   ├── tasks/main.yml         # установка AGH, фикс systemd-resolved (порт 53)
│   │   ├── handlers/main.yml
│   │   └── templates/AdGuardHome.yaml.j2   # конфиг; клиенты — циклом по adguard_clients
│   ├── k3s.yml                    # плейбук кластера: common → server → agents
│   ├── roles/k3s_common/          # подготовка нод (IPv4-preference, swap, guest-agent)
│   ├── roles/k3s_server/          # мастер + выгрузка kubeconfig на Mac
│   ├── roles/k3s_agent/           # воркеры (join по токену мастера)
│   └── inventory/                 # (gitignored) inventory генерирует Terraform
├── modules/
│   ├── adguard_lxc/               # ЕДИНЫЙ модуль: LXC-контейнер + запуск Ansible
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   └── k3s_cluster/               # QEMU-ВМ из cloud-image + bootstrap k3s через Ansible
└── envs/                          # окружения = площадки (свой state у каждой)
    ├── pve/
    │   ├── main.tf                # вызов модуля с топологией ноды pve
    │   ├── providers.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── terraform.tfvars.example
    │   └── terraform.tfvars       # (gitignored) реальные секреты + клиенты pve
    ├── pve-2/                      # то же самое для pve-2
    └── pve-k3s/                    # k3s-кластер на ноде pve (отдельный state)
```

**Принцип:** логика и структура конфига — общие (модуль + роль). Различия между квартирами — это *данные* в `terraform.tfvars` каждого окружения. Список клиентов у `pve` и `pve-2` разный и таким и должен быть.

## ⚙️ Как это работает

1. Terraform создаёт unprivileged LXC-контейнер (провайдер `bpg/proxmox`).
2. `remote-exec` ждёт готовности SSH в контейнере.
3. `local-exec` запускает Ansible-плейбук (`../../ansible/playbook.yml`, путь резолвится относительно модуля).
4. Ansible ставит AdGuard Home, освобождает порт 53 у `systemd-resolved`, раскатывает `AdGuardHome.yaml` из шаблона (пароль и клиенты подставляются из переменных).

## 🛠️ Быстрый старт

Требуется: `terraform` / `tofu` (>= 1.6), `ansible`, SSH-ключ с доступом к контейнеру, доступ к Proxmox API.

```bash
cd envs/pve            # или envs/pve-2

cp terraform.tfvars.example terraform.tfvars
# отредактируйте terraform.tfvars: пароли, хэш, список клиентов

terraform init
terraform plan
terraform apply
```

Панель будет доступна по адресу из output `adguard_web_interface`.

### Bcrypt-хэш пароля веб-панели

```bash
htpasswd -B -n -b bogdan 'ВАШ_ПАРОЛЬ'   # взять часть после "bogdan:"
```

### Добавить/изменить клиента

Отредактируйте `adguard_clients` в `terraform.tfvars` нужного окружения и выполните `terraform apply`. Никакие `.tf`-файлы и шаблоны трогать не нужно.

## 🔐 Секреты и состояние

`terraform.tfvars` (пароль Proxmox, bcrypt-хэш) и `terraform.tfstate` (содержит секреты в открытом виде) **не** коммитятся в git — они в `.gitignore`. Рекомендации по повышению безопасности:

1. **Перейти с root-пароля на Proxmox API-токен.** В `Datacenter → Permissions → API Tokens` создать токен и в `providers.tf` использовать:
   ```hcl
   provider "proxmox" {
     endpoint  = "https://192.168.1.10:8006/"
     api_token = var.proxmox_api_token   # "user@pam!tokenid=uuid-secret"
     insecure  = true
   }
   ```
   > Примечание: для bind-mount host-папки в контейнер может требоваться `root@pam` / `ssh`-подключение к ноде — проверьте права токена под свой сценарий.
2. Для шифрования секретов в репозитории рассмотреть **SOPS + age**.
3. `terraform.tfstate` и `*.tfvars` уже в `.gitignore`; `.terraform.lock.hcl` намеренно коммитится (фиксирует версию провайдера).

## 📝 Заметки

- Провайдер `bpg/proxmox` закреплён на `0.66.1`. Для обновления: `terraform init -upgrade` и проверить план.
- Публичный SSH-ключ задаётся дефолтом в `variables.tf` (`ssh_public_keys`) — при необходимости переопределяется в `terraform.tfvars`.
- `insecure = true` — из-за самоподписанного сертификата Proxmox в LAN.

---

## ☸️ k3s-кластер

Учебный кластер на ноде `pve`: 1 control-plane + 2 воркера, каждая VM — 2 vCPU / 2 GB RAM / 20 GB диска, Ubuntu 24.04 cloud-image.

| Узел           | VMID | IP             | MAC                 |
| -------------- | ---- | -------------- | ------------------- |
| `k3s-master`   | 200  | 192.168.1.30   | `BC:24:11:A0:30:30` |
| `k3s-worker-1` | 201  | 192.168.1.31   | `BC:24:11:A0:30:31` |
| `k3s-worker-2` | 202  | 192.168.1.32   | `BC:24:11:A0:30:32` |

Ставится стоковый k3s (Traefik + ServiceLB + local-path). Изменить набор — через `k3s_server_args` (например `["--disable", "traefik,servicelb"]`).

### Как это работает

1. Terraform скачивает Ubuntu cloud-image на ноду (`proxmox_virtual_environment_download_file`) и создаёт из него 3 ВМ с cloud-init (статические IP, SSH-ключ, пользователь `ubuntu`).
2. `remote-exec` на каждой ВМ ждёт `cloud-init status --wait`.
3. Terraform генерирует `ansible/inventory/k3s.ini` и запускает `ansible/k3s.yml`.
4. Ansible готовит ноды, ставит k3s server на мастере, забирает node-token и подключает воркеры, затем кладёт kubeconfig на Mac в `~/.kube/homelab-k3s` (адрес сервера подменён на IP мастера, контекст назван `homelab-k3s`).

### Перед первым apply

- **Зарезервировать MAC-адреса на роутере** (Keenetic) с политикой, разрешающей интернет. Новый случайный MAC попадает в ограниченный профиль без WAN — установка k3s тогда падает на скачивании.
- Убедиться, что `192.168.1.30–32` свободны и вне DHCP-пула.
- API-токен Proxmox с правами Administrator на ноде `pve` (тот же, что используется для AdGuard).

### Запуск

```bash
cd envs/pve-k3s
cp terraform.tfvars.example terraform.tfvars   # вписать секрет API-токена
tofu init
tofu plan
tofu apply
```

После этого:

```bash
export KUBECONFIG=~/.kube/homelab-k3s
kubectl get nodes -o wide
```

### Полезные ручки

- `k3s_channel` / `k3s_version` — канал (`stable`) или точная версия (`v1.31.5+k3s1`). Ansible переустанавливает k3s только когда версия или флаги реально изменились (сигнатура в `/etc/k3s-install.signature`).
- `qemu_agent_enabled` (модуль) — на первом apply обязательно `false`, иначе Terraform ждёт агента, которого в образе ещё нет. Ansible ставит пакет, но **не стартует** его: пока у ВМ нет `agent=1`, Proxmox не подключает virtio-канал `org.qemu.guest_agent.0`, а юнит к нему привязан. Чтобы включить агента потом: `qemu_agent_enabled = true` → `tofu apply` → перезагрузить ВМ (`qm reboot 200 201 202`) — канал появится, и systemd поднимет уже включённый сервис сам.
- Правки в ролях `k3s_*` или в плейбуке → повторный `tofu apply` перезапускает Ansible **без** пересоздания ВМ.
- Снести кластер целиком: `tofu destroy` в `envs/pve-k3s` (на AdGuard это не влияет — у окружений отдельные state).
