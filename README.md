# 🛡️ Proxmox AdGuard Home — Homelab IaC

Автоматизированное развёртывание AdGuard Home в LXC-контейнере на **двух** Proxmox-нодах с помощью Terraform + Ansible. Обе ноды описываются одним модулем и одной ролью Ansible; различаются только данными (клиенты, IP, секреты) в своих `terraform.tfvars`.

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
│   └── roles/adguard/
│       ├── tasks/main.yml         # установка AGH, фикс systemd-resolved (порт 53)
│       ├── handlers/main.yml
│       └── templates/AdGuardHome.yaml.j2   # конфиг; клиенты — циклом по adguard_clients
├── modules/
│   └── adguard_lxc/               # ЕДИНЫЙ модуль: LXC-контейнер + запуск Ansible
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── versions.tf
└── envs/                          # окружения = площадки (свой state у каждой)
    ├── pve/
    │   ├── main.tf                # вызов модуля с топологией ноды pve
    │   ├── providers.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── terraform.tfvars.example
    │   └── terraform.tfvars       # (gitignored) реальные секреты + клиенты pve
    └── pve-2/                      # то же самое для pve-2
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
