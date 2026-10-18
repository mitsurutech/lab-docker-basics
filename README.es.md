# Laboratorio de introducción a Docker con Docker Compose: aprende contenedores, registros y reinicios arreglando un servicio roto

[English](README.md) | [Français](README.fr.md) | [日本語](README.ja.md) | [Español](README.es.md)

[![check](https://github.com/mitsurutech/lab-docker-basics/actions/workflows/check.yml/badge.svg)](https://github.com/mitsurutech/lab-docker-basics/actions/workflows/check.yml)

Un **laboratorio de Docker para principiantes** listo para el aula, de la [plataforma de aprendizaje MitsuruTech](https://mitsurutech.co.uk/es/learning), donde escuelas y centros dan a cada alumno sus propias bases de datos, sus propios contenedores y su propio terminal en el navegador. Cada alumno recibe una pequeña pila de tres contenedores, uno de ellos **roto a propósito**. Lee sus registros para averiguar por qué se detuvo, echa un vistazo dentro de un contenedor sano, corrige el ajuste que faltaba, reinicia el servicio y lo ve arrancar en buen estado: `docker ps`, `docker logs`, `docker exec` y `docker restart`, sobre un Docker real, sin instalar nada y sin nada que pueda dañar el equipo de otra persona.

Es un único archivo `docker-compose`, `compose.yaml`, construido solo con imágenes públicas estándar (sin ningún Dockerfile), y funciona igual en tu propio equipo que en la plataforma, donde cada alumno tiene una copia privada sin salida a internet.

## Qué hace el alumno

1. **Ver qué se está ejecutando.** `docker ps` lista dos servicios, `web` y `cache`. Falta el worker. `docker ps -a` también lo muestra, con el estado `Exited (1)`: un contenedor detenido sigue ahí hasta que se elimina.
2. **Leer el registro.** `docker logs worker` dice exactamente por qué se detuvo: su archivo de ajustes no tiene una línea `QUEUE_HOST`, y `QUEUE_HOST` es el nombre del servicio que guarda la cola.
3. **Mirar dentro de un vecino sano.** `docker exec -it web sh` abre un shell dentro del contenedor `web`, que comparte una carpeta (un **volumen con nombre**) con el worker. `cat /settings/worker.conf` muestra el archivo que leyó el worker.
4. **Arreglarlo.** Añade la línea `QUEUE_HOST=cache` a `/settings/worker.conf` desde ese shell. Un nombre equivocado da otro error distinto, igual de claro, en el registro, lo cual también es buena práctica.
5. **Reiniciarlo.** `docker restart worker`; después `docker ps` lo muestra `Up` y `(healthy)`, y `docker logs worker` muestra trabajos terminándose. `docker exec cache valkey-cli get jobs_done` muestra el recuento creciendo en la cola.
6. **Ver qué dura.** La página que sirve `web` se escribió en el propio sistema de archivos de ese contenedor al arrancar. Sobrevive a `docker restart`, porque vuelve a arrancar el mismo contenedor, pero desaparece cuando el laboratorio se detiene y se vuelve a iniciar. El volumen con nombre que contiene `worker.conf` se conserva, así que la corrección permanece.

## Qué contiene

| Servicio | Imagen | Memoria | Qué es |
| --- | --- | --- | --- |
| `web` | [`nginx:1.27-alpine`](https://hub.docker.com/_/nginx) | 64 MB | sirve una página web y lista la carpeta de ajustes compartida en `/settings/` |
| `cache` | [`valkey/valkey:8.1-alpine`](https://hub.docker.com/r/valkey/valkey) | 64 MB | la cola de la que el worker toma trabajos (Valkey, que habla el protocolo de Redis) |
| `worker` | [`valkey/valkey:8.1-alpine`](https://hub.docker.com/r/valkey/valkey) | 32 MB | cuenta un trabajo terminado en la cola cada pocos segundos, una vez que se le dice dónde está la cola |

Los tres comparten un volumen con nombre, `settings`: `web` escribe en él `worker.conf` la primera vez que arranca y puede cambiarlo, y `worker` solo puede leerlo. Las dos imágenes están fijadas a una versión (nunca `latest`), así que el laboratorio no cambia bajo los pies de una clase de una lección a la siguiente. En una ejecución medida, los servicios estaban sanos unos cuatro segundos después de arrancar y usaban unos 17 MB entre todos en reposo.

Todo lo que hacen los servicios está escrito en las propias líneas `entrypoint:` del archivo compose, así que puedes leerlo todo, y aquí no se compila nada.

## Usarlo en la plataforma

La [plataforma de aprendizaje MitsuruTech](https://mitsurutech.co.uk/es/learning) da a cada alumno su propia copia de un laboratorio, en el navegador, con un terminal al lado. **En ese terminal `docker` es uno limitado**: `docker ps`, `docker logs`, `docker exec` y `docker restart` funcionan con los servicios del propio laboratorio, y no se puede crear, descargar, compilar ni eliminar nada. Eso es exactamente de lo que está hecho este laboratorio, y por eso un alumno nunca tiene que escribir un Dockerfile para hacerlo.

**Para probarlo:** abre la [página de contenedores](https://mitsurutech.co.uk/es/container), busca este laboratorio en **Laboratorios de ejemplo** y pulsa Iniciar. No hace falta cuenta para probar uno. La página del manual [lab-docker-basics](https://mitsurutech.co.uk/es/help/lab-docker-basics) lo recorre, y hay una lección corta, **Docker Basics**, que lo trabaja paso a paso.

**Para ponerlo como trabajo a una clase:**

1. En tu módulo, crea una tarea de tipo **Laboratorio** y elige **En un repositorio de GitHub**.
2. Indica `https://github.com/mitsurutech/lab-docker-basics` con la rama `main`. El archivo compose es el predeterminado, `compose.yaml`. Haz antes un fork del repositorio si quieres cambiar el archivo.
3. Publica. La copia de cada alumno parte del commit que publicaste, así que un cambio posterior aquí no altera un laboratorio ya puesto.
4. Di en la tarea qué hay que entregar (consulta [Para profesores](#para-profesores)) y asígnala como cualquier otra tarea.

La [guía de laboratorios de contenedores](https://mitsurutech.co.uk/es/help/labs) del manual de ayuda cuenta el resto: qué puede decir un archivo compose, cuánta memoria recibe una copia y cómo abre, observa y califica un profesor la copia de un alumno.

¿Aún no tienes una cuenta de centro? [El primer año es gratis](https://mitsurutech.co.uk/es/pricing) para hasta 50 alumnos, y [registrarse](https://mitsurutech.co.uk/es/signup) solo pide una dirección de correo electrónico.

## Ejecutarlo en tu propio equipo

Necesitas Docker con el complemento Compose. El primer arranque descarga las imágenes.

```bash
docker compose -f compose.yaml -f local.yaml up
```

Abre <http://localhost:8080> para ver la página que sirve `web`. `local.yaml` publica ese único puerto solo en `127.0.0.1`, así que el laboratorio es accesible desde tu propio ordenador y desde ningún otro sitio. En tu propio equipo tienes todo Docker, así que los comandos son los mismos con los nombres de contenedor del proyecto (`docker compose ps -a`, `docker compose logs worker`, `docker compose exec web sh`, `docker compose restart worker`). Deténlo con `Ctrl-C` y elimínalo con `docker compose -f compose.yaml -f local.yaml down -v`.

## Para profesores

Nada en este laboratorio se califica automáticamente. El alumno entrega pruebas y tú las calificas, igual que cualquier otro laboratorio.

**Pide pruebas que el servicio roto no pueda dar por casualidad.** La salida de `docker ps -a` antes de la corrección y la de `docker ps` después, la línea del registro que les dijo qué fallaba, y una frase que diga cuál de los archivos que escribieron sobreviviría a la detención del laboratorio, y por qué. La última te dice si entendieron la diferencia entre el sistema de archivos propio de un contenedor y un volumen, que es la idea para la que sirve este laboratorio.

**Dónde encaja en un curso.** Encaja en una introducción a los contenedores en una unidad de informática, redes o DevOps: qué es un contenedor, cómo leer lo que se está ejecutando, cómo te dice un servicio qué falla y por qué los datos que deben durar viven en un volumen. Consulta la redacción exacta en la unidad de tu propio organismo de certificación; aquí no se cita ninguna.

**Quién ve qué.** Una copia es privada para el alumno que la inició. Un miembro del personal que imparte el módulo puede abrirla para ver lo que ha hecho el alumno, y abrir el trabajo de un alumno queda escrito en el registro de accesos, que el alumno puede leer.

## Qué no funciona en un laboratorio

El laboratorio no tiene ninguna salida a internet, y nada en él la necesita. En el terminal de la plataforma, un alumno no puede iniciar, descargar, compilar ni eliminar contenedores, ni usar directamente volúmenes y redes: esos comandos se rechazan con una frase que lo dice. Son un buen tema para la siguiente conversación en clase, y funcionan en tu propio equipo.

## Solución de problemas

- **`docker ps` no muestra el worker.** Ese es el objetivo: se ha detenido. Usa `docker ps -a`.
- **El worker se detiene de nuevo tras la corrección.** Lee `docker logs worker`. Un nombre que no es un servicio del laboratorio se señala como tal: usa `cache`.
- **En tu propio equipo, el puerto 8080 ya está en uso.** Cambia el número de la izquierda en `local.yaml`, por ejemplo `127.0.0.1:8081:80`, y abre ese puerto en su lugar.

## Comprobación del laboratorio

`test/check.sh` inicia el laboratorio como el ejecutor de la plataforma inicia cada servicio (todas las capacidades retiradas salvo las que se devuelven a un servicio root, `no-new-privileges`, un límite de procesos, límites de memoria y ninguna salida a internet) y luego hace lo que hace un alumno: lee el registro del worker detenido, escribe un nombre equivocado y después el correcto desde un shell en `web`, reinicia el worker hasta que está sano y comprueba que solo el volumen con nombre sobrevive a la detención y el nuevo inicio del laboratorio. Necesita Docker y se ejecuta en cada push, que es la insignia de arriba.

```bash
test/check.sh
```

## Versiones y licencias

[nginx](https://nginx.org) está bajo licencia BSD-2-Clause y [Valkey](https://valkey.io), la bifurcación de código abierto de Redis, bajo licencia BSD-3-Clause. Las imágenes son `nginx:1.27-alpine` y `valkey/valkey:8.1-alpine`, ejecutadas sin modificar desde sus registros públicos, y ninguna se distribuye en este repositorio.

## Licencia

Esta obra está bajo licencia [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/). Puedes compartirla y adaptarla para aprender y enseñar, si citas a Mitsuru Technologies Ltd, no la usas comercialmente y compartes lo que hagas con ella bajo la misma licencia. El texto completo está en el archivo `LICENSE`.

## Acerca de

Hecho por [Mitsuru Technologies](https://mitsurutech.co.uk/es) para la [plataforma de aprendizaje MitsuruTech](https://mitsurutech.co.uk/es/learning): Python, Java, Go, Node, SQL y Linux en el navegador para escuelas y centros, con laboratorios de contenedores, aplicaciones web desplegadas desde GitHub y cuestionarios que se califican solos. Prueba código sin cuenta en el [entorno de pruebas](https://mitsurutech.co.uk/es/playground).

Más laboratorios del mismo sitio: [lab-juice-shop](https://github.com/mitsurutech/lab-juice-shop), [lab-dvwa](https://github.com/mitsurutech/lab-dvwa), [lab-webgoat](https://github.com/mitsurutech/lab-webgoat), [lab-mysql-phpmyadmin](https://github.com/mitsurutech/lab-mysql-phpmyadmin), [lab-git-gitea](https://github.com/mitsurutech/lab-git-gitea) y [lab-sample](https://github.com/mitsurutech/lab-sample).
