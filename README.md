This repository is made to illustrate an issue with propagation of updates applied to the list of DNS servers on
Ubuntu 18.04.3 LTS host server when running containerised application via Docker 19.03.8.

**Here is the scenario.**

1. Start a new AWS EC2 machine with Cloudflare as a DNS server. The environment is launched via Terraform (`terraform`).
The DHCP options `docker_test` should be selected for the VPC (`terraform/main.tf:91`).

2. Then upload a `docker/docker-compose.yaml` file and launch the service in daemon mode.

3. Then check current DNS servers selected viewing file `/etc/resolv.conf`.
The container's console may be accessed via `sudo docker-compose exec dnsutils bash`.

    - the host uses `127.0.0.53` managed by `systemd-resolve`;
    the result of `systemd-resolve --status` contains `DNS Servers: 1.1.1.1` as expected;
    - the container uses `127.0.0.11` which is embedded DNS server by Docker.

4. Then try to perform DNS requests to public and private DNS zones from the host and from the container.
It is possible to resolve publicly announced names, but the private DNS zone is not resolvable.
    ```
    ubuntu@ip-10-77-1-171:~$ dig ya.ru
    
    ; <<>> DiG 9.11.3-1ubuntu1.11-Ubuntu <<>> ya.ru
    ;; global options: +cmd
    ;; Got answer:
    ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 51166
    ;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
    
    ;; OPT PSEUDOSECTION:
    ; EDNS: version: 0, flags:; udp: 65494
    ;; QUESTION SECTION:
    ;ya.ru.				IN	A
    
    ;; ANSWER SECTION:
    ya.ru.			364	IN	A	87.250.250.242
    
    ;; Query time: 0 msec
    ;; SERVER: 127.0.0.53#53(127.0.0.53)
    ;; WHEN: Wed Apr 22 15:10:35 UTC 2020
    ;; MSG SIZE  rcvd: 50
    
    ubuntu@ip-10-77-1-171:~$ dig private.instance.docker.test.
    
    ; <<>> DiG 9.11.3-1ubuntu1.11-Ubuntu <<>> private.instance.docker.test.
    ---
    ;; global options: +cmd
    ;; Got answer:
    ;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 39041
    ;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 0, ADDITIONAL: 1
    
    ;; OPT PSEUDOSECTION:
    ; EDNS: version: 0, flags:; udp: 65494
    ;; QUESTION SECTION:
    ;private.instance.docker.test.	IN	A
    
    ;; Query time: 35 msec
    ;; SERVER: 127.0.0.53#53(127.0.0.53)
    ;; WHEN: Wed Apr 22 15:11:29 UTC 2020
    ;; MSG SIZE  rcvd: 57
    ```
    ```
    root@2d3a37ca5a24:/# dig ya.ru
    
    ; <<>> DiG 9.9.5-3ubuntu0.2-Ubuntu <<>> ya.ru
    ;; global options: +cmd
    ;; Got answer:
    ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 27599
    ;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
    
    ;; OPT PSEUDOSECTION:
    ; EDNS: version: 0, flags:; udp: 1452
    ;; QUESTION SECTION:
    ;ya.ru.				IN	A
    
    ;; ANSWER SECTION:
    ya.ru.			17	IN	A	87.250.250.242
    
    ;; Query time: 7 msec
    ;; SERVER: 127.0.0.11#53(127.0.0.11)
    ;; WHEN: Wed Apr 22 15:16:19 UTC 2020
    ;; MSG SIZE  rcvd: 50
    
    root@2d3a37ca5a24:/# dig private.instance.docker.test.
    
    ; <<>> DiG 9.9.5-3ubuntu0.2-Ubuntu <<>> private.instance.docker.test.
    ;; global options: +cmd
    ;; Got answer:
    ;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 36758
    ;; flags: qr rd ra ad; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1
    
    ;; OPT PSEUDOSECTION:
    ; EDNS: version: 0, flags:; udp: 1452
    ;; QUESTION SECTION:
    ;private.instance.docker.test.	IN	A
    
    ;; AUTHORITY SECTION:
    .			86400	IN	SOA	a.root-servers.net. nstld.verisign-grs.com. 2020042200 1800 900 604800 86400
    
    ;; Query time: 32 msec
    ;; SERVER: 127.0.0.11#53(127.0.0.11)
    ;; WHEN: Wed Apr 22 15:16:31 UTC 2020
    ;; MSG SIZE  rcvd: 132
    ```

5. Then apply changes to the DHCP options.
The DHCP options `docker_test_aws` should be selected for the VPC (`terraform/main.tf:91`).

6. Then wait for changes to be propagated to the host by monitoring `systemd-resolve --status`, for instance.
That could take some time up to an hour.

7. When the updates are received, it becomes possible to resolve private DNS records on the host.
    ```
    ubuntu@ip-10-77-1-171:~$ dig private.instance.docker.test.
    
    ; <<>> DiG 9.11.3-1ubuntu1.11-Ubuntu <<>> private.instance.docker.test.
    ;; global options: +cmd
    ;; Got answer:
    ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 3397
    ;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
    
    ;; OPT PSEUDOSECTION:
    ; EDNS: version: 0, flags:; udp: 65494
    ;; QUESTION SECTION:
    ;private.instance.docker.test.	IN	A
    
    ;; ANSWER SECTION:
    private.instance.docker.test. 295 IN	A	10.77.1.171
    
    ;; Query time: 0 msec
    ;; SERVER: 127.0.0.53#53(127.0.0.53)
    ;; WHEN: Wed Apr 22 15:52:46 UTC 2020
    ;; MSG SIZE  rcvd: 73
    ```

8. Then try to perform the similar request from the container. Though the embedded DNS server is claimed as proxy,
it will actually keep the configuration existed on the container startup.
    ```
    root@2d3a37ca5a24:/# dig private.instance.docker.test.
    
    ; <<>> DiG 9.9.5-3ubuntu0.2-Ubuntu <<>> private.instance.docker.test.
    ;; global options: +cmd
    ;; Got answer:
    ;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 12898
    ;; flags: qr rd ra ad; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1
    
    ;; OPT PSEUDOSECTION:
    ; EDNS: version: 0, flags:; udp: 1452
    ;; QUESTION SECTION:
    ;private.instance.docker.test.	IN	A
    
    ;; AUTHORITY SECTION:
    .			86400	IN	SOA	a.root-servers.net. nstld.verisign-grs.com. 2020042200 1800 900 604800 86400
    
    ;; Query time: 6 msec
    ;; SERVER: 127.0.0.11#53(127.0.0.11)
    ;; WHEN: Wed Apr 22 15:53:36 UTC 2020
    ;; MSG SIZE  rcvd: 132
    ```

9. Then restart the Docker service and try to resolve the private record again.
Since the restart leads to reinitialisation of the container, the resolution is performed successfully.
    ```
    ubuntu@ip-10-77-1-171:~$ sudo service docker restart
    ubuntu@ip-10-77-1-171:~$ sudo docker ps
    CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
    2d3a37ca5a24        tutum/dnsutils      "/bin/bash"         2 hours ago         Up 28 seconds                           ubuntu_dnsutils_1
    ```
    ```
    root@2d3a37ca5a24:/# dig private.instance.docker.test.
    
    ; <<>> DiG 9.9.5-3ubuntu0.2-Ubuntu <<>> private.instance.docker.test.
    ;; global options: +cmd
    ;; Got answer:
    ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 61797
    ;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 0
    
    ;; QUESTION SECTION:
    ;private.instance.docker.test.	IN	A
    
    ;; ANSWER SECTION:
    private.instance.docker.test. 300 IN	A	10.77.1.171
    
    ;; Query time: 15 msec
    ;; SERVER: 127.0.0.11#53(127.0.0.11)
    ;; WHEN: Wed Apr 22 17:37:32 UTC 2020
    ;; MSG SIZE  rcvd: 62
    
    root@2d3a37ca5a24:/# exit
    ```

10. Hence, it is clear, that the embedded DNS server provided by Docker ignores any changes to the DNS records
on the host machine applied by `systemd-resolve`.

**Here are some info regarding the Docker software used.**

```
ubuntu@ip-10-77-1-171:~$ sudo docker version
Client: Docker Engine - Community
 Version:           19.03.8
 API version:       1.40
 Go version:        go1.12.17
 Git commit:        afacb8b7f0
 Built:             Wed Mar 11 01:25:46 2020
 OS/Arch:           linux/amd64
 Experimental:      false

Server: Docker Engine - Community
 Engine:
  Version:          19.03.8
  API version:      1.40 (minimum version 1.12)
  Go version:       go1.12.17
  Git commit:       afacb8b7f0
  Built:            Wed Mar 11 01:24:19 2020
  OS/Arch:          linux/amd64
  Experimental:     false
 containerd:
  Version:          1.2.13
  GitCommit:        7ad184331fa3e55e52b890ea95e65ba581ae3429
 runc:
  Version:          1.0.0-rc10
  GitCommit:        dc9208a3303feef5b3839f4323d9beb36df0a9dd
 docker-init:
  Version:          0.18.0
  GitCommit:        fec3683
ubuntu@ip-10-77-1-171:~$ sudo docker info
Client:
 Debug Mode: false

Server:
 Containers: 2
  Running: 1
  Paused: 0
  Stopped: 1
 Images: 2
 Server Version: 19.03.8
 Storage Driver: overlay2
  Backing Filesystem: <unknown>
  Supports d_type: true
  Native Overlay Diff: true
 Logging Driver: json-file
 Cgroup Driver: cgroupfs
 Plugins:
  Volume: local
  Network: bridge host ipvlan macvlan null overlay
  Log: awslogs fluentd gcplogs gelf journald json-file local logentries splunk syslog
 Swarm: inactive
 Runtimes: runc
 Default Runtime: runc
 Init Binary: docker-init
 containerd version: 7ad184331fa3e55e52b890ea95e65ba581ae3429
 runc version: dc9208a3303feef5b3839f4323d9beb36df0a9dd
 init version: fec3683
 Security Options:
  apparmor
  seccomp
   Profile: default
 Kernel Version: 4.15.0-1057-aws
 Operating System: Ubuntu 18.04.3 LTS
 OSType: linux
 Architecture: x86_64
 CPUs: 2
 Total Memory: 461.5MiB
 Name: ip-10-77-1-171
 ID: 26BU:J23L:PORQ:CKTM:I6WQ:H6KT:6O4W:ZG5W:MBVL:DLH2:YC7P:56HV
 Docker Root Dir: /var/lib/docker
 Debug Mode: false
 Registry: https://index.docker.io/v1/
 Labels:
 Experimental: false
 Insecure Registries:
  127.0.0.0/8
 Live Restore Enabled: false

WARNING: No swap limit support
```
