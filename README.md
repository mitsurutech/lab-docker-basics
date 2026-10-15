# Docker basics lab with Docker Compose: learn containers, logs and restarts by fixing a broken service

[![check](https://github.com/mitsurutech/lab-docker-basics/actions/workflows/check.yml/badge.svg)](https://github.com/mitsurutech/lab-docker-basics/actions/workflows/check.yml)

A ready-made **Docker lab for beginners** for classrooms, from the [MitsuruTech Learning Platform](https://mitsurutech.co.uk/learning), where schools and colleges give every student their own databases, containers and terminal in the browser. Each student gets a small stack of three containers with one of them **broken on purpose**. They read its logs to find out why it stopped, look around inside a healthy container, fix the setting that was missing, restart the service and watch it come up healthy: `docker ps`, `docker logs`, `docker exec` and `docker restart`, on a real Docker, with nothing installed and nothing that can harm anybody else's machine.

It is one `docker-compose` file, `compose.yaml`, built only from stock public images (no Dockerfile at all), and it runs the same on your own machine as it does on the platform, where every student gets a private copy with no way out to the internet.

## What a student does

1. **See what is running.** `docker ps` lists two services, `web` and `cache`. The worker is missing. `docker ps -a` shows it too, with the status `Exited (1)`: a stopped container is still there until it is removed.
2. **Read the log.** `docker logs worker` says exactly why it stopped: its settings file has no `QUEUE_HOST` line, and `QUEUE_HOST` is the name of the service that keeps the queue.
3. **Look inside a healthy neighbour.** `docker exec -it web sh` opens a shell inside the `web` container, which shares a folder (a **named volume**) with the worker. `cat /settings/worker.conf` shows the file the worker read.
4. **Fix it.** Add the line `QUEUE_HOST=cache` to `/settings/worker.conf` from that shell. A wrong name is a different, equally clear error in the log, which is good practice too.
5. **Restart it.** `docker restart worker`, then `docker ps` shows it `Up` and `(healthy)`, and `docker logs worker` shows jobs being finished. `docker exec cache valkey-cli get jobs_done` shows the count growing in the queue.
6. **See what lasts.** The page `web` serves was written into that container's own filesystem when it started. It survives `docker restart`, because the same container starts again, but it is gone when the lab is stopped and started. The named volume holding `worker.conf` is kept, so the fix stays.

## What is in it

| Service | Image | Memory | What it is |
| --- | --- | --- | --- |
| `web` | [`nginx:1.27-alpine`](https://hub.docker.com/_/nginx) | 64 MB | serves a web page, and lists the shared settings folder at `/settings/` |
| `cache` | [`valkey/valkey:8.1-alpine`](https://hub.docker.com/r/valkey/valkey) | 64 MB | the queue the worker takes jobs from (Valkey, which speaks the Redis protocol) |
| `worker` | [`valkey/valkey:8.1-alpine`](https://hub.docker.com/r/valkey/valkey) | 32 MB | counts a finished job in the queue every few seconds, once it is told where the queue is |

The three share one named volume, `settings`: `web` writes `worker.conf` into it the first time it starts and can change it, and `worker` can only read it. Both images are pinned to a version (never `latest`), so the lab does not change under a class between one lesson and the next. In a measured run the services were healthy about four seconds after starting and used about 17 MB between them when idle.

Everything the services do is written in the compose file's own `entrypoint:` lines, so you can read all of it, and nothing is built here.

## Using it on the platform

The [MitsuruTech Learning Platform](https://mitsurutech.co.uk/learning) gives every student their own copy of a lab, in the browser, with a terminal beside it. **In that terminal `docker` is a limited one**: `docker ps`, `docker logs`, `docker exec` and `docker restart` work on the lab's own services, and nothing can be created, pulled, built or removed. That is exactly what this lab is made of, and it is why a student never has to write a Dockerfile to do it.

**To try it:** open the [container page](https://mitsurutech.co.uk/container), find this lab in **Sample labs** and press Start. No account is needed to try one. The manual page [lab-docker-basics](https://mitsurutech.co.uk/help/lab-docker-basics) walks through it, and there is a short lesson, **Docker Basics**, that works through it step by step.

**To set it as work for a class:**

1. In your module, make a task of type **Lab** and choose **In a GitHub repository**.
2. Give `https://github.com/mitsurutech/lab-docker-basics` with the branch `main`. The compose file is the default, `compose.yaml`. Fork the repository first if you want to change the file.
3. Publish. Every student's copy starts from the commit you published, so a later change here does not alter a lab already set.
4. Say in the task what to hand in (see [For teachers](#for-teachers)), and assign it like any other task.

The help manual's [guide to container labs](https://mitsurutech.co.uk/help/labs) covers the rest: what a compose file may say, how much memory a copy gets, and how a teacher opens, watches and marks a student's copy.

No college account yet? [Your first year is free](https://mitsurutech.co.uk/pricing) for up to 50 students, and [signing up](https://mitsurutech.co.uk/signup) takes an email address.

## Running it on your own machine

You need Docker with the Compose plugin. The first start downloads the images.

```bash
docker compose -f compose.yaml -f local.yaml up
```

Open <http://localhost:8080> to see the page `web` serves. `local.yaml` publishes that one port on `127.0.0.1` only, so the lab is reachable from your own computer and from nowhere else. On your own machine you have the whole of Docker, so the commands are the same ones with the project's container names (`docker compose ps -a`, `docker compose logs worker`, `docker compose exec web sh`, `docker compose restart worker`). Stop it with `Ctrl-C`, and remove it with `docker compose -f compose.yaml -f local.yaml down -v`.

## For teachers

Nothing in this lab is marked automatically. The student hands in evidence and you mark it, the way you mark any other lab.

**Ask for evidence the broken service cannot give by accident.** The output of `docker ps -a` before the fix and `docker ps` after it, the line of the log that told them what was wrong, and a sentence saying which of the files they wrote would survive the lab stopping, and why. The last one tells you whether they understood a container's own filesystem against a volume, which is the idea this lab is for.

**Where it sits in a course.** It suits an introduction to containers in a computing, networking or DevOps unit: what a container is, how to read what is running, how a service tells you what is wrong, and why data that has to last lives in a volume. Check your own awarding body's unit for the exact wording; none is quoted here.

**Who sees what.** A copy is private to the student who started it. A member of staff who teaches the module can open it to see what the student has done, and opening a student's work is written to the access log, which the student can read.

## What does not work in a lab

The lab has no way out to the internet at all, and nothing in it needs one. In the platform's terminal a student cannot start, pull, build or remove containers, or use volumes and networks directly: those commands are refused with a sentence saying so. They are a good next conversation in class, and they work on your own machine.

## Troubleshooting

- **`docker ps` does not show the worker.** That is the point: it has stopped. Use `docker ps -a`.
- **The worker stops again after the fix.** Read `docker logs worker`. A name that is not a service in the lab is reported as such: use `cache`.
- **On your own machine, port 8080 is already in use.** Change the left-hand number in `local.yaml`, for example `127.0.0.1:8081:80`, and open that port instead.

## Checking the lab

`test/check.sh` starts the lab the way the platform's runner starts every service (all capabilities dropped except what a root service is given back, `no-new-privileges`, a process limit, memory limits, and no way out to the internet) and then does what a student does: reads the log of the stopped worker, writes a wrong name and then the right one from a shell in `web`, restarts the worker until it is healthy, and checks that only the named volume survives the lab being stopped and started. It needs Docker and runs on every push, which is the badge at the top.

```bash
test/check.sh
```

## Versions and licences

[nginx](https://nginx.org) is under a BSD-2-Clause licence and [Valkey](https://valkey.io), the open source fork of Redis, is under the BSD-3-Clause licence. The images are `nginx:1.27-alpine` and `valkey/valkey:8.1-alpine`, run unmodified from their public registries, and neither is distributed in this repository.

The compose file, the tests and this documentation are MIT licensed, see [LICENSE](LICENSE): copy it, change it, teach with it.

## About

Made by [Mitsuru Technologies](https://mitsurutech.co.uk) for the [MitsuruTech Learning Platform](https://mitsurutech.co.uk/learning): Python, Java, Go, Node, SQL and Linux in the browser for schools and colleges, with container labs, web apps deployed from GitHub, and quizzes that mark themselves. Try code with no account in the [playground](https://mitsurutech.co.uk/playground).

More labs from the same place: [lab-juice-shop](https://github.com/mitsurutech/lab-juice-shop), [lab-dvwa](https://github.com/mitsurutech/lab-dvwa), [lab-webgoat](https://github.com/mitsurutech/lab-webgoat), [lab-mysql-phpmyadmin](https://github.com/mitsurutech/lab-mysql-phpmyadmin), [lab-git-gitea](https://github.com/mitsurutech/lab-git-gitea) and [lab-sample](https://github.com/mitsurutech/lab-sample).
