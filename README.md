# MariaDB Galera Multi-Cluster Infrastructure

Infrastruktura IaC (Terraform + Ansible) dla klastrów MariaDB Galera na Proxmox VE.

## Architektura

```
                       ┌──────────────┐
                       │    lb-1      │  192.168.1.55
                       │   HAProxy    │  Prod: 3306w/3307r
                       │   ProxySQL   │  Dev:  3308w/3309r
                       └──────┬───────┘
                              │
            ┌─────────────────┼─────────────────┐
            │                 │                 │
     ┌──────┴───────┐  ┌─────┴──────┐  ┌───────┴──────┐
     │  PROD        │  │  grafana-1 │  │  DEV         │
     │  .51-.53     │  │  .54       │  │  .61-.63     │
     │  galera-1/2/3│  │ Prometheus │  │ galera-dev-  │
     │              │  │ Grafana    │  │  1/2/3       │
     └──────────────┘  │ PMM        │  └──────────────┘
                       └────────────┘
```

| Host | IP | Rola |
|------|----|------|
| galera-1 | 192.168.1.51 | Prod Galera node 1 (bootstrap) |
| galera-2 | 192.168.1.52 | Prod Galera node 2 |
| galera-3 | 192.168.1.53 | Prod Galera node 3 + backup |
| grafana-1 | 192.168.1.54 | Prometheus + Grafana + PMM |
| lb-1 | 192.168.1.55 | HAProxy + ProxySQL |
| galera-dev-1 | 192.168.1.61 | Dev Galera node 1 (bootstrap) |
| galera-dev-2 | 192.168.1.62 | Dev Galera node 2 |
| galera-dev-3 | 192.168.1.63 | Dev Galera node 3 + backup |

## Struktura repo

```
.
├── main.tf / rocky9.tf / variables.tf    # Terraform: Rocky 9 template + standalone VM
│
├── galera/                               # Klaster PROD
│   ├── terraform/                        # 5 VM: 3 galera + lb + monitoring
│   │   ├── main.tf
│   │   ├── nodes.tf                      # galera-1/2/3 (VM 501-503)
│   │   ├── loadbalancer.tf               # lb-1 (VM 505)
│   │   ├── monitoring.tf                 # grafana-1 (VM 504)
│   │   └── variables.tf / outputs.tf
│   │
│   └── ansible/                          # Konfiguracja wszystkich hostow
│       ├── ansible.cfg
│       ├── site.yml                      # Glowny playbook
│       ├── inventory/
│       │   ├── hosts.yml                 # Wszystkie hosty (prod + dev)
│       │   └── group_vars/
│       │       ├── all.yml               # Wspolne zmienne + galera_clusters
│       │       ├── galera_prod.yml       # Hasla i usery prod
│       │       ├── galera_dev.yml        # Hasla i usery dev
│       │       └── loadbalancer.yml      # Konfiguracja LB
│       └── roles/
│           ├── common/                   # System bazowy, NTP, limity
│           ├── firewall/                 # firewalld
│           ├── mariadb/                  # MariaDB 11.4 instalacja
│           ├── galera/                   # Konfiguracja klastra + bootstrap
│           ├── haproxy/                  # HAProxy (multi-cluster)
│           ├── haproxy-check/            # opcjonalny legacy xinetd health check
│           ├── proxysql/                 # ProxySQL (multi-cluster)
│           ├── prometheus-exporter/      # mysqld_exporter na nodach
│           ├── monitoring/               # Prometheus + Grafana + PMM
│           └── backup/                   # mariabackup + cron
│
└── galera-dev/                           # Klaster DEV
    └── terraform/                        # 3 VM: galera-dev-1/2/3 (VM 601-603)
        ├── main.tf
        ├── nodes.tf
        └── variables.tf / outputs.tf
```

## Wymagania

- Proxmox VE 8.x z szablonem Rocky 9 (VM ID 9001)
- Terraform >= 1.5.0
- Ansible >= 2.15 z kolekcjami:
  ```bash
  cd galera/ansible
  ansible-galaxy collection install -r requirements.yml
  ```
- SSH klucz ed25519 (`~/.ssh/id_ed25519`)
- Proxmox API token (`tf-rocky@pve!provider`)

## Szybki start

### 1. Terraform: tworzenie VM

Repo root (`main.tf`, `rocky9.tf`) sluzy do zarzadzania szablonem Rocky 9 (VM ID 9001)
oraz dodatkowa testowa VM. Glowny deploy prod/dev zaczyna sie od katalogow ponizej.

```bash
# Prod (5 VM: 3 galera + lb + monitoring)
cd galera/terraform
cp terraform.tfvars.example terraform.tfvars  # uzupelnij proxmox_api_token
terraform init && eval $(ssh-agent) && ssh-add && terraform apply

# Dev (3 VM: galera-dev-1/2/3)
cd galera-dev/terraform
cp terraform.tfvars.example terraform.tfvars
terraform init && eval $(ssh-agent) && ssh-add && terraform apply
```

### 2. Ansible: deploy klastra

```bash
cd galera/ansible
ansible-galaxy collection install -r requirements.yml

# Pelny deploy wszystkiego (bez opcjonalnej roli haproxy-check)
ansible-playbook site.yml

# Tylko prod
ansible-playbook site.yml --tags prod

# Tylko dev
ansible-playbook site.yml --tags dev

# Tylko LB (rekonfiguracja HAProxy + ProxySQL)
ansible-playbook site.yml --tags loadbalancer

# Tylko monitoring
ansible-playbook site.yml --tags monitoring

# Tylko backup
ansible-playbook site.yml --tags backup

# Opcjonalny legacy health check przez xinetd
# Uzywaj tylko na systemie, gdzie xinetd jest dostepny
ansible-playbook site.yml --tags haproxy-check -e galera_enable_haproxy_check=true
```

### 3. Szybka walidacja

```bash
# Szybki check z repo root
make validate

# Terraform validate (po `terraform init` w kazdym root)
make terraform-validate

# Rownowazne komendy recznie:
terraform validate
(cd galera/terraform && terraform validate)
(cd galera-dev/terraform && terraform validate)

# Ansible syntax
cd galera/ansible
ansible-playbook site.yml --syntax-check
```

## Laczenie z baza danych

### Przez HAProxy (aplikacja wybiera port)

Podstaw swoje hasla z `inventory/group_vars/*.yml` albo z Ansible Vault.

```bash
# PROD
mysql -h 192.168.1.55 -P 3306 -u sbtest -p'<APP_PASSWORD>'         # write
mysql -h 192.168.1.55 -P 3307 -u sbtest -p'<APP_PASSWORD>'         # read

# DEV
mysql -h 192.168.1.55 -P 3308 -u sbtest_dev -p'<APP_PASSWORD>'  # write
mysql -h 192.168.1.55 -P 3309 -u sbtest_dev -p'<APP_PASSWORD>'  # read
```

### Przez ProxySQL (automatyczny read/write split)

```bash
# PROD — ProxySQL sam rozdziela SELECT na readery, reszta na writera
mysql -h 192.168.1.55 -P 6033 -u sbtest -p'<APP_PASSWORD>'

# DEV — routing po username, ten sam port
mysql -h 192.168.1.55 -P 6033 -u sbtest_dev -p'<APP_PASSWORD>'
```

### Bezposrednio na node (diagnostyka)

```bash
ssh rocky@192.168.1.51
sudo mariadb
```

## HAProxy vs ProxySQL

| | HAProxy | ProxySQL |
|---|---------|----------|
| Porty | 3306/3307 (prod), 3308/3309 (dev) | 6033 (wspolny) |
| Izolacja klastrow | po portach | po username |
| Read/write split | aplikacja wybiera port | automatyczny (analiza SQL) |
| Failover | automatyczny | automatyczny |
| Kiedy uzywac | prosta aplikacja, sam kontrolujesz | chcesz automatyzm bez zmian w app |

W produkcji wybierasz jedno. Oba sa zainstalowane na lb-1 do nauki.

## Monitoring

| Usluga | URL |
|---------|-----|
| Grafana | http://192.168.1.54:3000 (admin/admin, zmien po pierwszym logowaniu) |
| Prometheus | http://192.168.1.54:9090 |
| PMM Server | https://192.168.1.54:8443 (admin/admin, zmien po pierwszym logowaniu) |
| HAProxy Stats | http://192.168.1.55:8404/stats |

Prometheus scrape'uje:
- `galera_prod` — 3 nody mysqld_exporter (:9104) z labelem `cluster=prod`
- `galera_dev` — 3 nody mysqld_exporter (:9104) z labelem `cluster=dev`
- `haproxy` — metryki HAProxy (:8405)
- `proxysql` — proxysql_exporter (:42004)

## Backup

Backup (mariabackup) dziala na **ostatnim nodzie** kazdego klastra:
- Prod: galera-3 (.53)
- Dev: galera-dev-3 (.63)

| Harmonogram | Co |
|-------------|----|
| Niedziela 2:00 | Pelny backup |
| Pn-Sb co 4h | Inkrementalny backup |
| Codziennie 3:30 | Czyszczenie (retencja 30 dni) |

Katalog: `/var/backups/mariadb`

```bash
# Reczny pelny backup
ssh rocky@192.168.1.53
sudo /usr/local/bin/galera-backup-full.sh

# Restore (zatrzymuje MariaDB!)
sudo /usr/local/bin/galera-restore.sh

# Sprawdz logi
sudo tail -f /var/log/galera-backup.log
```

Backup jest fizyczny (mariabackup) — kopiuje caly `/var/lib/mysql`. Nowe bazy sa automatycznie objete backupem.

## Diagnostyka

### Status klastra Galera

```bash
# Z dowolnego noda
sudo mariadb -e "SHOW GLOBAL STATUS LIKE 'wsrep_%'" | grep -E 'cluster_size|cluster_status|ready|local_state_comment'
```

Prawidlowy wynik:
```
wsrep_cluster_size           3
wsrep_cluster_status         Primary
wsrep_ready                  ON
wsrep_local_state_comment    Synced
```

### Status ProxySQL

```bash
# Na lb-1
sudo mysql -u admin -h 127.0.0.1 -P 6032 -p'<PROXYSQL_ADMIN_PASSWORD>' \
  -e "SELECT hostgroup_id, hostname, status FROM runtime_mysql_servers ORDER BY hostgroup_id"
```

### Status HAProxy

```bash
# Na lb-1
echo "show stat" | sudo socat /var/lib/haproxy/stats stdio | cut -d, -f1,2,18 | column -t -s,
```

### Logi

```bash
# MariaDB
sudo journalctl -u mariadb -f

# HAProxy
sudo journalctl -u haproxy -f

# ProxySQL
sudo tail -f /var/lib/proxysql/proxysql.log
```

## Hostgroups ProxySQL

| HG | Rola | Klaster |
|----|------|---------|
| 10 | Writer | Prod |
| 11 | Backup writer | Prod |
| 12 | Reader | Prod |
| 13 | Offline | Prod |
| 20 | Writer | Dev |
| 21 | Backup writer | Dev |
| 22 | Reader | Dev |
| 23 | Offline | Dev |

## Dodawanie nowego usera aplikacji

1. Edytuj `galera/ansible/inventory/group_vars/galera_prod.yml` (lub `galera_dev.yml`):
   ```yaml
   app_users:
     - name: "sbtest"
       password: "SbTest2024"
       priv: "*.*:ALL PRIVILEGES"
     - name: "myapp"                    # nowy user
       password: "MyAppPassword2024"
       priv: "mydb.*:ALL PRIVILEGES"
   ```

2. Uruchom:
   ```bash
   ansible-playbook site.yml --tags mariadb,proxysql
   ```

## Dodawanie trzeciego klastra

1. Stworz `galera-staging/terraform/` (kopia z `galera-dev/terraform/`, zmien IP/VM ID)
2. Dodaj grupe `galera_staging` w `inventory/hosts.yml`
3. Dodaj `inventory/group_vars/galera_staging.yml` z haslami
4. Dodaj wpis do `galera_clusters` w `inventory/group_vars/all.yml`:
   ```yaml
   - name: staging
     galera_group: galera_staging
     haproxy_write_port: 3310
     haproxy_read_port: 3311
     proxysql_writer_hostgroup: 30
     proxysql_backup_writer_hostgroup: 31
     proxysql_reader_hostgroup: 32
     proxysql_offline_hostgroup: 33
   ```
5. Dodaj plays w `site.yml` z `tags: [staging]`
6. `terraform apply` + `ansible-playbook site.yml --tags staging,loadbalancer,monitoring`

## Wazne uwagi

- **Hasla**: W produkcji uzyj `ansible-vault` do szyfrowania hasel w group_vars
- **SSH agent**: Terraform wymaga ssh-agent w tej samej sesji: `eval $(ssh-agent) && ssh-add && terraform apply`
- **HAProxy health check**: HAProxy uzywa natywnego `option mysql-check` — nie wymaga xinetd ani dodatkowych skryptow
- **ProxySQL monitor**: Oba klastry musza miec tego samego usera `proxysql_monitor` z tym samym haslem (ProxySQL ma jedno globalne konto monitora)
- **wsrep_provider_options**: Musi byc single-line — multiline lamie parser Galera

## Linting

Repo zawiera konfiguracje pre-commit z ansible-lint i terraform validate:

```bash
pip install pre-commit ansible-lint
pre-commit install
pre-commit run --all-files
```
