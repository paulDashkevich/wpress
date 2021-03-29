#домашняя работа: настройка конфигурации веб приложения под высокую нагрузку

Цель работы:
> terraform и ansible роль для развертывания серверов веб приложения под высокую нагрузку и отказоустойчивость в работе должны применяться:

>keepalived,
>nginx,
>uwsgi/unicorn/php-fpm
>некластеризованная бд mysql/mongodb/postgres/redis
>gfs2 должна быть реализована
>отказоустойчивость бэкенд и nginx серверов
>отказоустойчивость сессий
>фэйловер без потери статического контента должны быть реализованы ansible скрипты с тюнингом
>параметров sysctl
>лимитов
>настроек nginx
>включением пулов соединений

1. Конфигурация terraform разворачивает 6 серверов для создания стенда: 
+ прокси-сервер для работы с внешним адресом, 
+ сервер для базы данных,
+ сервер с iscsi-целью 
+ сервер с ролью quorum-device
+ два сервера с ролями nginx, keepalived, php-fpm, pacemaker

2. Ansible поочерёдно выполняет установку и настройку софта. Для старта необходимо установить requirements.yml. Далее, после успешной отработки терраформа, запускаем 
```
ansible-playbook ansible/playbooks/environment.yml
```

3. Проверка стенда сводится к следующему: 
+ заходим на любую ноду сервера через ssh и проверяем статус кластера:
```
[root@web0 adminroot]# pcs status
Cluster name: ha_cluster
Stack: corosync
Current DC: web0 (version 1.1.23-1.el7_9.1-9acf116022) - partition with quorum
Last updated: Mon Mar 29 16:53:41 2021
Last change: Mon Mar 29 16:39:10 2021 by root via cibadmin on web0

2 nodes configured
9 resource instances configured

Online: [ web0 web1 ]

Full list of resources:

 Clone Set: dlm-clone [dlm]
     Started: [ web0 web1 ]
 Clone Set: clvmd-clone [clvmd]
     Started: [ web0 web1 ]
 Clone Set: clusterfs-clone [clusterfs]
     Started: [ web0 web1 ]
 webserver      (ocf::heartbeat:nginx): Started web0
 php-fpm        (systemd:php-fpm.service):      Started web0
 keepalived     (systemd:keepalived):   Started web0

Daemon Status:
  corosync: active/enabled
  pacemaker: active/enabled
  pcsd: active/enabled
```
Все службы и ресурсы кластера в рабочем состоянии и запущены на ноде web0.
+ для проверки работоспособности кластера переключаться между нодами (поскольку задача актив/бэкап) у хостера не предусмотрена возможность задействовать fencing device (stonith) можно положить ноду командой 
```
pcs cluster standby web0
```
которая переведёт ноду в режим ожидания, но позволит увидеть работу кластера: ресурсы перейдут в рабочее состояние на второй ноде кластера web1

```
[root@web0 adminroot]# pcs status
Cluster name: ha_cluster
Stack: corosync
Current DC: web0 (version 1.1.23-1.el7_9.1-9acf116022) - partition with quorum
Last updated: Mon Mar 29 16:58:18 2021
Last change: Mon Mar 29 16:57:58 2021 by root via cibadmin on web0

2 nodes configured
9 resource instances configured

Node web0: standby (with active resources)
Online: [ web1 ]

Full list of resources:

 Clone Set: dlm-clone [dlm]
     Started: [ web0 web1 ]
 Clone Set: clvmd-clone [clvmd]
     Started: [ web0 web1 ]
 Clone Set: clusterfs-clone [clusterfs]
     Started: [ web0 web1 ]
 webserver      (ocf::heartbeat:nginx): Started web1
 php-fpm        (systemd:php-fpm.service):      Started web1
 keepalived     (systemd:keepalived):   Started web1

Daemon Status:
  corosync: active/enabled
  pacemaker: active/enabled
  pcsd: active/enabled
```
из выкладки видно, что ресурсы теперь работают на запасной ноде без заметной потери в работе сайта, он по прежнему доступен по адресу прокси-сервера.
включаем ноду обратно командой 
```
pcs cluster unstandby web0
```
и наблюдаем быстрое восстановление работы служб на первой ноде web0
```
[root@web0 adminroot]# pcs status
Cluster name: ha_cluster
Stack: corosync
Current DC: web0 (version 1.1.23-1.el7_9.1-9acf116022) - partition with quorum
Last updated: Mon Mar 29 17:01:12 2021
Last change: Mon Mar 29 17:00:39 2021 by root via cibadmin on web0

2 nodes configured
9 resource instances configured

Online: [ web0 web1 ]

Full list of resources:

 Clone Set: dlm-clone [dlm]
     Started: [ web0 web1 ]
 Clone Set: clvmd-clone [clvmd]
     Started: [ web0 web1 ]
 Clone Set: clusterfs-clone [clusterfs]
     Started: [ web0 web1 ]
 webserver      (ocf::heartbeat:nginx): Started web0
 php-fpm        (systemd:php-fpm.service):      Started web0
 keepalived     (systemd:keepalived):   Started web0

Daemon Status:
  corosync: active/enabled
  pacemaker: active/enabled
  pcsd: active/enabled
```
Задача выполнена.
