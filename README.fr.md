# Lab d’initiation à Docker avec Docker Compose : apprendre conteneurs, journaux et redémarrages en réparant un service en panne

[English](README.md) | [Français](README.fr.md) | [日本語](README.ja.md) | [Español](README.es.md)

[![check](https://github.com/mitsurutech/lab-docker-basics/actions/workflows/check.yml/badge.svg)](https://github.com/mitsurutech/lab-docker-basics/actions/workflows/check.yml)

Un **lab Docker pour débutants** prêt à l’emploi pour la classe, issu de la [plateforme d’apprentissage MitsuruTech](https://mitsurutech.co.uk/fr/learning), où les écoles et les établissements donnent à chaque élève ses propres bases de données, ses propres conteneurs et son propre terminal dans le navigateur. Chaque élève reçoit une petite pile de trois conteneurs dont l’un est **en panne volontairement**. Il lit ses journaux pour comprendre pourquoi il s’est arrêté, jette un œil à l’intérieur d’un conteneur en bonne santé, corrige le paramètre manquant, redémarre le service et le regarde passer à l’état sain : `docker ps`, `docker logs`, `docker exec` et `docker restart`, sur un vrai Docker, sans rien installer et sans rien qui puisse nuire à la machine de quelqu’un d’autre.

C’est un seul fichier `docker-compose`, `compose.yaml`, construit uniquement à partir d’images publiques standard (aucun Dockerfile), et il fonctionne de la même façon sur votre propre machine que sur la plateforme, où chaque élève dispose d’une copie privée sans aucune sortie vers Internet.

## Ce que fait l’élève

1. **Voir ce qui tourne.** `docker ps` liste deux services, `web` et `cache`. Le worker manque. `docker ps -a` le montre aussi, avec l’état `Exited (1)` : un conteneur arrêté est toujours là tant qu’on ne l’a pas supprimé.
2. **Lire le journal.** `docker logs worker` dit exactement pourquoi il s’est arrêté : son fichier de paramètres n’a pas de ligne `QUEUE_HOST`, et `QUEUE_HOST` est le nom du service qui tient la file d’attente.
3. **Regarder à l’intérieur d’un voisin en bonne santé.** `docker exec -it web sh` ouvre un shell dans le conteneur `web`, qui partage un dossier (un **volume nommé**) avec le worker. `cat /settings/worker.conf` montre le fichier que le worker a lu.
4. **Le réparer.** Ajoutez la ligne `QUEUE_HOST=cache` à `/settings/worker.conf` depuis ce shell. Un nom erroné donne une autre erreur, tout aussi claire, dans le journal, ce qui est aussi un bon exercice.
5. **Le redémarrer.** `docker restart worker`, puis `docker ps` le montre `Up` et `(healthy)`, et `docker logs worker` montre des tâches en cours d’achèvement. `docker exec cache valkey-cli get jobs_done` montre le compteur qui grandit dans la file d’attente.
6. **Voir ce qui dure.** La page que sert `web` a été écrite dans le propre système de fichiers de ce conteneur au démarrage. Elle survit à `docker restart`, car c’est le même conteneur qui redémarre, mais elle disparaît quand le lab est arrêté puis relancé. Le volume nommé qui contient `worker.conf` est conservé, donc la correction reste.

## Ce que contient le lab

| Service | Image | Mémoire | Ce que c’est |
| --- | --- | --- | --- |
| `web` | [`nginx:1.27-alpine`](https://hub.docker.com/_/nginx) | 64 Mo | sert une page web, et liste le dossier de paramètres partagé à `/settings/` |
| `cache` | [`valkey/valkey:8.1-alpine`](https://hub.docker.com/r/valkey/valkey) | 64 Mo | la file d’attente où le worker prend ses tâches (Valkey, qui parle le protocole Redis) |
| `worker` | [`valkey/valkey:8.1-alpine`](https://hub.docker.com/r/valkey/valkey) | 32 Mo | compte une tâche terminée dans la file d’attente toutes les quelques secondes, dès qu’on lui dit où elle se trouve |

Les trois partagent un volume nommé, `settings` : `web` y écrit `worker.conf` la première fois qu’il démarre et peut le modifier, et `worker` ne peut que le lire. Les deux images sont figées sur une version (jamais `latest`), si bien que le lab ne change pas sous les pieds d’une classe d’une leçon à l’autre. Lors d’une exécution mesurée, les services étaient sains environ quatre secondes après le démarrage et utilisaient environ 17 Mo à eux trois au repos.

Tout ce que font les services est écrit dans les lignes `entrypoint:` du fichier compose, vous pouvez donc tout lire, et rien n’est construit ici.

## L’utiliser sur la plateforme

La [plateforme d’apprentissage MitsuruTech](https://mitsurutech.co.uk/fr/learning) donne à chaque élève sa propre copie d’un lab, dans le navigateur, avec un terminal à côté. **Dans ce terminal, `docker` est une version limitée** : `docker ps`, `docker logs`, `docker exec` et `docker restart` fonctionnent sur les services du lab, et rien ne peut être créé, téléchargé, construit ni supprimé. C’est exactement de quoi ce lab est fait, et c’est pourquoi un élève n’a jamais à écrire un Dockerfile pour le faire.

**Pour l’essayer :** ouvrez la [page des conteneurs](https://mitsurutech.co.uk/fr/container), trouvez ce lab dans **Laboratoires d’exemple** et appuyez sur Démarrer. Aucun compte n’est nécessaire pour en essayer un. La page du manuel [lab-docker-basics](https://mitsurutech.co.uk/fr/help/lab-docker-basics) le détaille, et une courte leçon, **Docker Basics**, le déroule pas à pas.

**Pour le donner comme travail à une classe :**

1. Dans votre module, créez une tâche de type **Lab** et choisissez **Dans un dépôt GitHub**.
2. Indiquez `https://github.com/mitsurutech/lab-docker-basics` avec la branche `main`. Le fichier compose est celui par défaut, `compose.yaml`. Faites d’abord un fork du dépôt si vous voulez modifier le fichier.
3. Publiez. La copie de chaque élève part du commit que vous avez publié : une modification ultérieure ici ne change donc pas un lab déjà donné.
4. Dites dans la tâche ce qu’il faut rendre (voir [Pour les enseignants](#pour-les-enseignants)), et distribuez-la comme n’importe quelle autre tâche.

Le [guide des labs de conteneurs](https://mitsurutech.co.uk/fr/help/labs) du manuel d’aide dit le reste : ce qu’un fichier compose peut contenir, combien de mémoire reçoit une copie, et comment un enseignant ouvre, observe et corrige la copie d’un élève.

Pas encore de compte d’établissement ? [La première année est gratuite](https://mitsurutech.co.uk/fr/pricing) pour 50 élèves au plus, et [s’inscrire](https://mitsurutech.co.uk/fr/signup) ne demande qu’une adresse e-mail.

## L’exécuter sur votre propre machine

Il vous faut Docker avec le plugin Compose. Le premier démarrage télécharge les images.

```bash
docker compose -f compose.yaml -f local.yaml up
```

Ouvrez <http://localhost:8080> pour voir la page que sert `web`. `local.yaml` ne publie ce port que sur `127.0.0.1`, si bien que le lab est accessible depuis votre propre ordinateur et nulle part ailleurs. Sur votre propre machine, vous disposez de tout Docker : les commandes sont donc les mêmes avec les noms de conteneurs du projet (`docker compose ps -a`, `docker compose logs worker`, `docker compose exec web sh`, `docker compose restart worker`). Arrêtez-le avec `Ctrl-C`, et supprimez-le avec `docker compose -f compose.yaml -f local.yaml down -v`.

## Pour les enseignants

Rien dans ce lab n’est corrigé automatiquement. L’élève rend des preuves et vous les corrigez, comme pour n’importe quel autre lab.

**Demandez des preuves que le service en panne ne peut pas fournir par hasard.** La sortie de `docker ps -a` avant la réparation et de `docker ps` après, la ligne du journal qui leur a dit ce qui n’allait pas, et une phrase disant lequel des fichiers qu’ils ont écrits survivrait à l’arrêt du lab, et pourquoi. Cette dernière vous dit s’ils ont compris la différence entre le système de fichiers propre d’un conteneur et un volume, l’idée même de ce lab.

**Sa place dans un cours.** Il convient à une introduction aux conteneurs dans une unité d’informatique, de réseaux ou de DevOps : ce qu’est un conteneur, comment lire ce qui tourne, comment un service dit ce qui ne va pas, et pourquoi les données qui doivent durer vivent dans un volume. Vérifiez le libellé exact dans l’unité de votre propre organisme certificateur ; aucun n’est cité ici.

**Qui voit quoi.** Une copie est privée pour l’élève qui l’a démarrée. Un membre du personnel qui enseigne le module peut l’ouvrir pour voir ce que l’élève a fait, et l’ouverture du travail d’un élève est inscrite dans le journal d’accès, que l’élève peut lire.

## Ce qui ne marche pas dans un lab

Le lab n’a aucune sortie vers Internet, et rien n’en a besoin. Dans le terminal de la plateforme, un élève ne peut pas démarrer, télécharger, construire ni supprimer de conteneurs, ni utiliser directement des volumes et des réseaux : ces commandes sont refusées avec une phrase qui le dit. Elles font un bon sujet de discussion pour la suite en classe, et elles fonctionnent sur votre propre machine.

## Dépannage

- **`docker ps` n’affiche pas le worker.** C’est voulu : il s’est arrêté. Utilisez `docker ps -a`.
- **Le worker s’arrête de nouveau après la correction.** Lisez `docker logs worker`. Un nom qui n’est pas un service du lab est signalé comme tel : utilisez `cache`.
- **Sur votre propre machine, le port 8080 est déjà utilisé.** Changez le nombre de gauche dans `local.yaml`, par exemple `127.0.0.1:8081:80`, et ouvrez plutôt ce port.

## Vérification du lab

`test/check.sh` démarre le lab comme le runner de la plateforme démarre chaque service (toutes les capacités retirées sauf ce qu’un service root retrouve, `no-new-privileges`, une limite de processus, des limites de mémoire et aucune sortie vers Internet), puis fait ce que fait un élève : lit le journal du worker arrêté, écrit un mauvais nom puis le bon depuis un shell dans `web`, redémarre le worker jusqu’à ce qu’il soit sain, et vérifie que seul le volume nommé survit à l’arrêt puis au redémarrage du lab. Il a besoin de Docker et s’exécute à chaque push, ce qu’indique le badge en haut.

```bash
test/check.sh
```

## Versions et licences

[nginx](https://nginx.org) est sous licence BSD-2-Clause et [Valkey](https://valkey.io), le fork open source de Redis, est sous licence BSD-3-Clause. Les images sont `nginx:1.27-alpine` et `valkey/valkey:8.1-alpine`, exécutées sans modification depuis leurs registres publics, et aucune n’est distribuée dans ce dépôt.

## Licence

Cette œuvre est sous licence [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/). Vous pouvez la partager et l’adapter pour apprendre et enseigner, à condition de citer Mitsuru Technologies Ltd, de ne pas l’utiliser commercialement et de partager tout ce que vous en tirez sous la même licence. Le texte complet est dans le fichier `LICENSE`.

## À propos

Réalisé par [Mitsuru Technologies](https://mitsurutech.co.uk/fr) pour la [plateforme d’apprentissage MitsuruTech](https://mitsurutech.co.uk/fr/learning) : Python, Java, Go, Node, SQL et Linux dans le navigateur pour les écoles et les établissements, avec des labs de conteneurs, des applications web déployées depuis GitHub et des quiz qui se corrigent tout seuls. Essayez du code sans compte dans le [bac à sable](https://mitsurutech.co.uk/fr/playground).

D’autres labs du même endroit : [lab-juice-shop](https://github.com/mitsurutech/lab-juice-shop), [lab-dvwa](https://github.com/mitsurutech/lab-dvwa), [lab-webgoat](https://github.com/mitsurutech/lab-webgoat), [lab-mysql-phpmyadmin](https://github.com/mitsurutech/lab-mysql-phpmyadmin), [lab-git-gitea](https://github.com/mitsurutech/lab-git-gitea) et [lab-sample](https://github.com/mitsurutech/lab-sample).
