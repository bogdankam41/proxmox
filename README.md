# 🛡️ Proxmox Homelab IaC

Terraform + Ansible для домашней инфраструктуры на Proxmox:

- **AdGuard Home** в LXC-контейнере на **двух** нодах (`envs/pve`, `envs/pve-2`); на `pve-2` контейнер вторым интерфейсом смотрит ещё и в гостевую сеть;
- **k3s-кластер** (1 мастер + 2 воркера) на ноде `pve` (`envs/pve-k3s`) — см. раздел [☸️ k3s-кластер](#️-k3s-кластер);
- **стек мониторинга** (Prometheus + Alertmanager + Grafana) на ноде `pve` (`envs/pve-monitoring`) — см. раздел [📈 Мониторинг](#-мониторинг).

AdGuard: автоматизированное развёртывание в LXC-контейнере на двух Proxmox-нодах. Обе ноды описываются одним модулем и одной ролью Ansible; различаются только данными (клиенты, IP, секреты) в своих `terraform.tfvars`.

## 🌐 Топология

Две площадки, соединённые site-to-site **IPSec-туннелем**:

```
   Квартира 1 (дом)                            Квартира 2
   LAN 192.168.1.0/24                           LAN 192.168.2.0/24
                                                гости 192.168.3.0/24 (VLAN 2)
 ┌────────────────────────────┐  IPSec   ┌──────────────────────────────┐
 │ Proxmox "pve"              │◀────────▶│ Proxmox "pve-2"              │
 │  192.168.1.10              │ туннель  │  192.168.2.10                │
 │                            │          │                              │
 │  LXC adguard-home          │          │  LXC adguard-home (2 NIC)    │
 │   192.168.1.2 (DNS)        │          │   eth0      192.168.2.2 (DNS)│
 │                            │          │   net-guest 192.168.3.2 (DNS)│
 │  VM k3s-master   .1.30     │          └──────────────────────────────┘
 │  VM k3s-worker-1 .1.31     │
 │  VM k3s-worker-2 .1.32     │
 │  VM monitoring   .1.40     │
 └────────────────────────────┘
```

| Параметр            | `pve` (дом)        | `pve-2` (вторая квартира) |
| ------------------- | ------------------ | ------------------------- |
| Proxmox endpoint    | `192.168.1.10:8006`| `192.168.2.10:8006`       |
| Подсеть             | `192.168.1.0/24`   | `192.168.2.0/24`          |
| IP контейнера AGH   | `192.168.1.2`      | `192.168.2.2`             |
| Gateway             | `192.168.1.1`      | `192.168.2.1`             |
| VMID контейнера     | `100`              | `100`                     |
| Веб-панель          | `http://192.168.1.2` | `http://192.168.2.2`    |
| Второй NIC (гости)  | —                  | `192.168.3.2`, VLAN 2     |
| Что ещё на ноде     | k3s, мониторинг    | —                         |

### Гостевая сеть на `pve-2`

У контейнера на `pve-2` два интерфейса: `eth0` в домашней сети (`192.168.2.2`, на нём
default route) и `net-guest` в гостевой (`192.168.3.2`, VLAN 2, с включённым файрволом
Proxmox). Гостевым устройствам нужен только DNS — маршрута в домашнюю сеть у них нет.
Описывается это опциональной переменной модуля `guest_interface` (`envs/pve-2/main.tf`):

```hcl
guest_interface = {
  name        = "net-guest"
  ip          = "192.168.3.2"
  cidr        = 24
  bridge      = "vmbr0"
  vlan_id     = 2
  firewall    = true
  mac_address = "BC:24:11:E1:8D:0A"
}
```

`guest_interface = null` (значение по умолчанию, как на `pve`) — контейнер с одним NIC.
Шлюз второму интерфейсу намеренно не задаётся: default route держит основной.

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
│   ├── monitoring.yml             # плейбук стека мониторинга
│   ├── roles/monitoring/          # Prometheus + Alertmanager + Grafana
│   │   └── files/dashboards/      # свои дашборды Grafana (температура)
│   ├── node_exporter.yml          # поставить экспортер на любое устройство
│   ├── roles/node_exporter/       # node_exporter + systemd-юнит
│   └── inventory/                 # (gitignored) inventory генерирует Terraform
├── modules/
│   ├── adguard_lxc/               # ЕДИНЫЙ модуль: LXC-контейнер + запуск Ansible
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   ├── k3s_cluster/               # QEMU-ВМ из cloud-image + bootstrap k3s через Ansible
│   └── monitoring_vm/             # одна QEMU-ВМ со стеком мониторинга
└── envs/                          # окружения = площадки (свой state у каждой)
    ├── pve/
    │   ├── main.tf                # вызов модуля с топологией ноды pve
    │   ├── providers.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── terraform.tfvars.example
    │   └── terraform.tfvars       # (gitignored) реальные секреты + клиенты pve
    ├── pve-2/                      # то же самое для pve-2 (+ второй NIC в гостевую сеть)
    ├── pve-k3s/                    # k3s-кластер на ноде pve (отдельный state)
    └── pve-monitoring/             # стек мониторинга на ноде pve (отдельный state)
```

**Принцип:** логика и структура конфига — общие (модуль + роль). Различия между квартирами — это *данные* в `terraform.tfvars` каждого окружения. Список клиентов у `pve` и `pve-2` разный и таким и должен быть.

## ⚙️ Как это работает

1. Terraform создаёт unprivileged LXC-контейнер (провайдер `bpg/proxmox`).
2. `remote-exec` ждёт готовности SSH в контейнере.
3. `local-exec` запускает Ansible-плейбук (`../../ansible/playbook.yml`, путь резолвится относительно модуля).
4. Ansible ставит AdGuard Home нужной версии (бинарь из GitHub-релиза), освобождает порт 53 у `systemd-resolved`, раскатывает `AdGuardHome.yaml` из шаблона (пароль и клиенты подставляются из переменных).

Ресурсы контейнера и версии — дефолты модуля `adguard_lxc`, переопределяются в окружении:

| Параметр          | Значение по умолчанию                                    |
| ----------------- | -------------------------------------------------------- |
| `memory_mb`       | `256` (AdGuard в простое ест ~150 MiB)                     |
| `swap_mb`         | `512`                                                      |
| `disk_size`       | `8` GiB, датастор `local-lvm`                              |
| `os_template`     | `ubuntu-26.04-standard_26.04-1_amd64.tar.zst`              |
| `adguard_version` | `v0.107.79` — пришпилена намеренно                         |

Апгрейд/откат AdGuard — это смена `adguard_version` + `tofu apply`: роль сравнивает
версию установленного бинаря с запрошенной и переустанавливает его только при
расхождении, контейнер при этом не пересоздаётся.

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

`terraform.tfvars` (секрет токена Proxmox, bcrypt-хэш, пароль Grafana, токен Telegram) и `terraform.tfstate` (содержит секреты в открытом виде) **не** коммитятся в git — они в `.gitignore`.

**Аутентификация в Proxmox — API-токен во всех четырёх окружениях.** `providers.tf` собирает его из двух переменных:

```hcl
api_token = "${var.proxmox_user}=${var.proxmox_password}"
```

То есть `proxmox_user` — это **полный идентификатор токена** `user@realm!tokenid`, а `proxmox_password` — его секрет (uuid). Токен создаётся в `Datacenter → Permissions → API Tokens`; для k3s и мониторинга используется `terraform@pve!terraform` с правами Administrator на ноде.

> В `envs/pve` и `envs/pve-2` у переменной `proxmox_user` остался дефолт `root@pam` — со времён парольной аутентификации. Его обязательно нужно переопределить в `terraform.tfvars` полным `root@pam!<tokenid>` (или отдельным токеном), иначе строка токена будет невалидной.

Провайдер дополнительно ходит на ноду **по SSH** (`ssh { username = "root" }`) — часть операций уровня ноды через API не делается. Ключ берётся из `ssh_key_path`.

Что ещё стоит сделать:

1. Для шифрования секретов в репозитории рассмотреть **SOPS + age**.
2. `terraform.tfstate` и `*.tfvars` уже в `.gitignore`; `.terraform.lock.hcl` намеренно коммитится (фиксирует версию провайдера).

## 📝 Заметки

- Провайдер `bpg/proxmox` закреплён на `0.66.1`. Для обновления: `terraform init -upgrade` и проверить план.
- Публичный SSH-ключ задаётся дефолтом в `variables.tf` (`ssh_public_keys`) — при необходимости переопределяется в `terraform.tfvars`.
- `insecure = true` — из-за самоподписанного сертификата Proxmox в LAN.

---

## ☸️ k3s-кластер

Учебный кластер на ноде `pve`: 1 control-plane + 2 воркера, по 2 vCPU и 20 GB диска, Ubuntu 24.04 cloud-image. RAM задаётся на ноду (`memory_mb` внутри `master`/`workers`), общий `memory_mb` модуля — фоллбэк для тех, кто своё значение не указал.

| Узел           | VMID | IP             | RAM     | MAC                 |
| -------------- | ---- | -------------- | ------- | ------------------- |
| `k3s-master`   | 200  | 192.168.1.30   | 4096 MB | `BC:24:11:A0:30:30` |
| `k3s-worker-1` | 201  | 192.168.1.31   | 4096 MB | `BC:24:11:A0:30:31` |
| `k3s-worker-2` | 202  | 192.168.1.32   | 4096 MB | `BC:24:11:A0:30:32` |

DNS нодам раздаётся через cloud-init и указывает на AdGuard (`192.168.1.2`): запросы
кластера фильтруются и видны в query log. Роутер был только bootstrap-резолвером —
на первом развёртывании, пока на AdGuard ещё нельзя было полагаться.

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
- Изменение RAM/CPU — это in-place update конфига ВМ: Ansible не перезапускается, но QEMU видит новый объём только после stop/start (провайдер перезапускает сам, иначе `qm reboot <vmid>`). Делать по одной ноде, чтобы поды успевали переезжать.
- Снести кластер целиком: `tofu destroy` в `envs/pve-k3s` (на AdGuard это не влияет — у окружений отдельные state).

---

## 📈 Мониторинг

Одна ВМ на ноде `pve` со всем стеком: **Prometheus** (сбор + правила алертов), **Alertmanager** (доставка), **Grafana** (дашборды) и **node_exporter** (метрики самой ВМ).

| Параметр   | Значение                              |
| ---------- | ------------------------------------- |
| VMID       | `210`                                 |
| IP         | `192.168.1.40`                        |
| MAC        | `BC:24:11:A0:30:40`                   |
| RAM / vCPU | 3072 MB / 2                           |
| Диск       | 32 GB (на нём лежит TSDB Prometheus)  |
| Grafana    | `http://192.168.1.40:3000`            |
| Prometheus | `http://192.168.1.40:9090`            |
| Alertmanager | `http://192.168.1.40:9093`          |
| DNS        | `192.168.1.2` (AdGuard)               |

### ➕ Добавить новое устройство

Ровно как клиенты AdGuard: правится **только** `terraform.tfvars`, `.tf`-файлы и шаблоны трогать не нужно.

1. Поставить на устройство экспортер — плейбук [`ansible/node_exporter.yml`](ansible/node_exporter.yml) ставит `node_exporter` на любой Linux-хост (бинарь из GitHub-релиза + systemd-юнит, слушает `:9100`). Запускается из корня репозитория:

   ```bash
   # k3s-ноды — через inventory, сгенерированный Terraform
   ansible-playbook -i ansible/inventory/k3s.ini ansible/node_exporter.yml

   # ноды Proxmox (Debian, вход root); pve-2 — через IPSec-туннель
   ansible-playbook -i '192.168.1.10,' -u root \
     --private-key ~/.ssh/private-key-ed25519 ansible/node_exporter.yml
   ansible-playbook -i '192.168.2.10,' -u root \
     --private-key ~/.ssh/private-key-ed25519 ansible/node_exporter.yml

   # LXC с AdGuard (вход root)
   ansible-playbook -i '192.168.1.2,' -u root \
     --private-key ~/.ssh/private-key-ed25519 ansible/node_exporter.yml

   # произвольный хост с обычным пользователем и sudo
   ansible-playbook -i '192.168.1.50,' -u ubuntu \
     --private-key ~/.ssh/private-key-ed25519 ansible/node_exporter.yml
   ```

   Плейбук идемпотентен: повторный запуск ничего не меняет, а смена `node_exporter_version` переустанавливает бинарь. Проверить: `curl -s http://<ip>:9100/metrics | head`.

2. Добавить его в `monitoring_targets` в `envs/pve-monitoring/terraform.tfvars`:

   ```hcl
   monitoring_targets = [
     { name = "pve",    address = "192.168.1.10:9100", labels = { role = "hypervisor" } },
     { name = "nas",    address = "192.168.1.50:9100" },
     # устройство со своим экспортером — в отдельный job:
     { name = "router", address = "192.168.1.1:9100", job = "network" },
   ]
   ```

   | Поле      | Обязательно | Смысл                                                    |
   | --------- | ----------- | -------------------------------------------------------- |
   | `name`    | да          | имя в Grafana и в тексте алертов                          |
   | `address` | да          | `host:port` экспортера (`node_exporter` слушает `:9100`)  |
   | `job`     | нет         | scrape job; по умолчанию `node`                           |
   | `labels`  | нет         | дополнительные метки (`{ role = "k3s" }`)                 |

3. `tofu apply` — Terraform перезапустит Ansible, ВМ **не** пересоздаётся.

Проверить результат: `http://192.168.1.40:9090/targets` — все цели должны быть `UP`. Цель в состоянии `DOWN` обычно значит, что на устройстве не поднят экспортер (шаг 1) или порт закрыт файрволом.

Устройства одного job лежат в отдельном файле `/etc/prometheus/targets/<job>.json` (file_sd), поэтому добавление устройства в существующий job Prometheus подхватывает сам, даже без перезагрузки конфига. Новый `job` добавляет scrape-конфиг в `prometheus.yml` → роль шлёт Prometheus SIGHUP (reload, без простоя).

### 🔔 Алерты

Встроенные правила: `InstanceDown` (цель не отвечает 5 мин), `HighCpuUsage`, `HighMemoryUsage`, `LowDiskSpace`, `HighTemperature` (см. [🌡️ Температура](#️-температура)). Пороги правятся из tfvars:

```hcl
alert_thresholds = {
  alert_disk_threshold = "90"   # по умолчанию 85%
  alert_cpu_for        = "15m"  # по умолчанию 10m
  alert_temp_threshold = "90"   # по умолчанию 85 °C
}
```

Доставка — Telegram; пока `telegram_bot_token` пустой, алерты считаются и видны в UI, но никуда не уходят:

```hcl
telegram_bot_token = "123456:ABC..."
telegram_chat_id   = "987654321"
```

Совсем выключить правила — `alerts_enabled = false`.

### 🌡️ Температура

Отдельный экспортер не нужен: коллектор `hwmon` включён в `node_exporter` по умолчанию и читает `/sys/class/hwmon`, то есть всё, для чего в ядре загружен драйвер. Обе ноды — ноутбуки Dell (`pve` — XPS 15 9560, `pve-2` — XPS 13 9365), набор чипов у них одинаковый:

| Чип                       | Что это                                       |
| ------------------------- | --------------------------------------------- |
| `platform_coretemp_0`     | Intel CPU: `temp1` — пакет, дальше ядра        |
| `nvme_nvme0`              | NVMe-накопитель                                |
| `platform_dell_smm_hwmon` | датчики и **вентиляторы** платы Dell           |
| `thermal_thermal_zone*`   | ACPI-зоны и чипсет (`pch_skylake`)             |

Метрики: `node_hwmon_temp_celsius{chip,sensor}`, обороты — `node_hwmon_fan_rpm`. Человекочитаемое имя сенсора лежит отдельно, в `node_hwmon_sensor_label` (у `coretemp` `temp1` → `Package id 0`).

Быстрая проверка, что железо вообще отдаёт температуру, — до установки экспортера:

```bash
ssh root@192.168.1.10 'for d in /sys/class/hwmon/hwmon*; do echo "$d: $(cat $d/name)"; done'
```

Пусто или только `acpitz` — значит драйвер не загружен: поставьте `lm-sensors`, прогоните `sensors-detect` и допишите нужные модули (`nct6775`, `it87`, `drivetemp` для SATA-дисков) в `/etc/modules`. Ни на `pve`, ни на `pve-2` этого не потребовалось — `coretemp`, `nvme` и `dell_smm` подхватываются сами.

`pve-2` скрейпится **через IPSec-туннель** (`192.168.2.10:9100`, RTT ~3 мс) — наружу порт экспортера открывать не надо, туннель уже несёт LAN второй площадки.

**Дашборд:** «Homelab — температура» (`ansible/roles/monitoring/files/dashboards/homelab-temperature.json`) — максимум по хостам, CPU, диски, все сенсоры, вентиляторы; фильтры по хосту и чипу. Список хостов строится из самих метрик (`label_values(node_hwmon_temp_celsius, name)`), поэтому новая нода с датчиками появляется на дашборде сама, править JSON не нужно. Температура есть и в Node Exporter Full — свёрнутая строка *Hardware Misc*.

**Алерт:** `HighTemperature` — выше `alert_temp_threshold` (85 °C) дольше `alert_temp_for` (5 мин). Правило смотрит только на чипы из `alert_temp_chips` (CPU и диски): ACPI-зоны, батарея и часть датчиков платы на многих машинах врут (у `dell_smm` один сенсор стабильно показывает 0 °C), поэтому в правило они не входят — на дашборде видны все.

### 📊 Дашборды

Grafana получает Prometheus-датасорс и папку `Homelab` через provisioning — руками ничего подключать не надо.

**Добавить дашборд с grafana.com** (способ «как надо», остаётся в IaC). На странице дашборда — например <https://grafana.com/grafana/dashboards/1860> — берётся его ID и номер ревизии, и добавляется в `grafana_dashboards` в `terraform.tfvars`:

```hcl
grafana_dashboards = [
  { name = "node-exporter-full",  gnet_id = 1860, revision = 37 },
  { name = "prometheus-overview", gnet_id = 3662, revision = 2 },
  { name = "alertmanager",        gnet_id = 9578, revision = 4 },
]
```

`tofu apply` — JSON скачивается в `/var/lib/grafana/dashboards/<name>.json`, плейсхолдер датасорса в нём подменяется на провиженный Prometheus, Grafana перезапускается и дашборд появляется в папке `Homelab`. Удалили строку → `apply` → дашборд убирается из списка (сам файл при этом остаётся на диске, если он больше не нужен — снести вручную).

**Свой дашборд в репозитории.** JSON, положенный в `ansible/roles/monitoring/files/dashboards/`, раскатывается сам — так живёт температурный дашборд. Датасорс в файле пишется плейсхолдером `${DS_PROMETHEUS}`, роль подменяет его на провиженный Prometheus при копировании. Собрать такой можно в UI: `Export → Save to file`, затем положить файл в эту папку и сделать `tofu apply`.

**Свой дашборд в UI.** Собрать в UI → `Share → Export → Save to file` → положить JSON рядом и раскатывать копированием, либо (проще) оставить его жить в UI: у провижининга стоит `allowUiUpdates: true`, так что править провиженные дашборды и создавать новые через интерфейс можно. Но созданное в UI живёт только в базе Grafana на ВМ и пропадёт при пересоздании ВМ — в отличие от того, что описано в `grafana_dashboards`.

> Ревизия пришпилена намеренно: обновление дашборда автором не поменяет ваш борд молча. Хотите новее — поднимите `revision` (у Node Exporter Full актуальная — 45).

### Запуск

```bash
cd envs/pve-monitoring
cp terraform.tfvars.example terraform.tfvars   # токен API, пароль Grafana, список устройств
tofu init
tofu plan
tofu apply
```

### Заметки

- **Зарезервировать MAC на роутере** (как для k3s) — иначе ВМ попадает в ограниченный профиль без WAN и установка падает на скачивании.
- `192.168.1.40` должен быть свободен и вне DHCP-пула.
- Cloud-image (`noble-server-cloudimg-amd64.img`) уже качает `envs/pve-k3s`, поэтому здесь стоит `download_image = false` — окружение просто использует готовый файл. Если разворачивать мониторинг на ноде без k3s, поставить `true`.
- `qemu_agent_enabled` — та же логика, что у k3s: на первом apply `false`, потом `true` + перезагрузка ВМ.
- **Grafana Labs отдаёт 403 на российские IP** (`apt.grafana.com`, `dl.grafana.com`). Если ВМ ходит в интернет напрямую, задача `Fetch the Grafana apt signing key` падает с `HTTP Error 403: Access Denied` — нужен обход у ВМ (весь остальной стек ставится с GitHub и блокировкой не задет).
- Версии компонентов пришпилены переменными модуля (`prometheus_version`, `alertmanager_version`, `node_exporter_version`, `grafana_version`). Бинарь переустанавливается, только если версия на диске реально отличается.
- Ретеншн метрик — `prometheus_retention_time` (по умолчанию 30 дней); увеличивая его, увеличивайте и `disk_size`.
- Правки в роли `monitoring` → повторный `tofu apply` перезапускает Ansible **без** пересоздания ВМ.
