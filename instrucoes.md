## Clonar repositório

`https://github.com/fernando-alves/pokenode`

## Rodar testes

No diretório raiz, executar `npm install` e depois `npm test`. As instruções estão no README do projeto.

## Executar aplicação

No diretório raiz, executar `npm start`.

> Error: Redis connection to localhost:6379 failed - connect ECONNREFUSED 127.0.0.1:6379

App não conseguiu achar o banco de dados, precisamos de um.

## Executando o Redis a partir de container

Pull da imagem padrão `docker image pull redis`. Executar container `docker container run redis`.

Se listarmos os containers `docker container ls`

| CONTAINER ID | IMAGE | COMMAND | CREATED | STATUS | PORTS | NAMES |
|--------------|-------|---------|---------|--------|-------|-------|
| 6740b6c4f3ba | redis | "docker-entrypoint..." | 59 seconds ago | Up 57 seconds | 6379/tcp | awesome_euclid |

Agora podemos executar novamente a aplicação `npm start`, mas mesmo assim ela não deve conseguir conectar ao banco. Por que?

## Portas

O ports do container mostra 6379/tcp, mas ela não deve estar mapeada para nenhuma no host.

Executar `docker container port 6740b6c4f3ba` deve retornar uma lista vazia.

Como mapear as portas? 2 opções no docker container run:

- -P: mapeia as portas para portas randomicas no host
- -p \<container-port\>:
\<host-port\>: mapeia as portas específicas

Assim, podemos exeutar `docker container run -p 6379:6379 redis`.

O container em execução agora tem a porta mapeada para o host `docker container ls`

| CONTAINER ID | IMAGE | COMMAND | CREATED | STATUS | PORTS | NAMES |
|--------------|-------|---------|---------|--------|-------|-------|
| d4bd5134b4ba | postgres | "docker-entrypoint..." | 59 seconds ago | Up 57 seconds | 0.0.0.0:6379->6379/tcp | angry_darwin |

`docker container port d4bd5134b4ba`

> 0.0.0.0:6379->6379/tcp

Finalmente podemos executar `npm start` e visitar http://localhost:8080/

## Executando em segundo plano

O comando `docker container run -p 6379:6379 -d redis` executará o container em segundo plano.

## Movendo a aplicação para um container

Do que nossa aplicação precisa pra executar?

- Node
- curl para instalar o node
- Código fonte!

A partir de uma máquina nova (assumindo ubuntu), como instalar essas dependências?

## Criando uma imagem para nossa aplicação

Precisamos de um `Dockerfile`, ele é a descrição da imagem.

Daí, nosso ponto de partida é o própria distribuição:

```
FROM ubuntu:latest
```

Para criar a imagem, usamos o comando `docker image build .`

> Sending build context to Docker daemon  1.19 MB
Step 1/1 : FROM ubuntu:latest
latest: Pulling from library/ubuntu
75c416ea735c: Pull complete
c6ff40b6d658: Pull complete
a7050fc1f338: Pull complete
f0ffb5cf6ba9: Pull complete
be232718519c: Pull complete
Digest: sha256:a0ee7647e24c8494f1cf6b94f1a3cd127f423268293c25d924fbe18fd82db5a4
Status: Downloaded newer image for ubuntu:latest
 ---> d355ed3537e9
Successfully built d355ed3537e9

Vamos instalar o curl, necessário para instalar o NodeJS:

```
RUN apt-get update && \
apt-get install -y curl && \
apt-get clean
```

Novamente, `docker image build .`

| REPOSITORY | TAG | IMAGE ID | CREATED | SIZE |
|------------|-----|----------|---------|------|
| \<none\> | \<none\> | e791248e891e | About a minute ago | 142 MB |

Agora podemos instalar o NodeJS:

```
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash
RUN apt-get update && apt-get install -y nodejs && apt-get clean
```

Depender de `latest` não é uma boa prática, vamos mudar para 18.04 (versão LTS):

```
FROM ubuntu:18.04
```

## Dando nome a nossa imagem

Podemos associar uma tag a imagem criada usando a opção `-t`:

`docker image build . -t pokenode`

| REPOSITORY | TAG | IMAGE ID | CREATED | SIZE |
|------------|-----|----------|---------|------|
| pokenode | latest | e791248e891e | About a minute ago | 142 MB |

## Usando o docker-compose para facilitar nossa vida

Compose é uma ferramenta para descrição e execução de aplicações com múltiples containers. O Compose encapsula alguns comandos básicos do Docker de forma que podemos utilizá-lo de uma maneira declarativa.

Para isso, precisamos de um arquivo `docker-compose.yml` onde vamos descrever nossa aplicação. Nesse ponto, a única coisa que fazemos é construir sua image.

Cada componente da aplicação é definido por um serviço no Compose:

```
version: '3.6'
services:
  app:
    build: .
    image: pokenode

```

Agora podemos criar uma versão nova da imagem usando `docker-compose build`, sem a necessidade de explicitar a tag ou contexto.

## Usando a imagem

Vamos entrar no container pra saber se tudo foi instalado corretamente: `docker container run pokenode /bin/bash`

O `docker container run <imagem> <comando>` o comando em container baseado na imagem. A vida do container é associada diretamente ao processo do comando, assim que encerrado, o container parará.

Para manter a sessão, devemos utilizar as opções `-i` (modo interativo) e `-t` (para alocar um tty) do comando `run`.

Dessa vez, executaremos: `docker container run -ti pokenode /bin/bash`

Outros comandos interessantes: `docker container ls`, `docker container start` e `docker container stop`.

## Código fonte

Copiar arquivos do host para a image é feito usando o comando `COPY`:

```
COPY . /app
```

Devemos recriar a image, `docker-compose build`, e então podemos verificar se o código está por lá `docker container run pokenode ls /app`

## Diretório padrão

Para que todos os comandos do `run` executem a partir do diretório /app, podemos usar:

```
WORKDIR /app
```

## Instalando dependências

Antes de qualquer coisa precisamos instalar as dependências, para isso, excutamos `npm install` e recriamos a image.

Por padrão, `npm` instala as dependências no diretório `node_modules` na raiz do projeto. Quando copiamos os arquivos, esse diretório também é incluso.

Isso pode acarretar em problemas, dado que o ambiente do host é diferente do container. Podemos indicar ao Docker que ignore o diretório usando o arquivo `.dockerignore`.

```
node_modules
```

## Executando testes a partir do container

Já com o código e as dependências instaladas, podemos executar os testes a partir do container: `docker container run -ti pokenode npm test`.

## Executando testes com a ajuda do Compose

Podemos simplificar a execução dos testes usando `docker-compose run --rm app npm test`.

## Quais outros serviços ela precisa?

Em execução, o aplicação precisa do banco de dados. Nesse caso temos 2 opções:

- Instalar e executar redis dentro do container: Não é uma boa prática. Por que?
- Usar o container do redis: irado!

## Network

Por padrão docker cria uma rede docker0 que é compartilhada por todos os containers. Mas não queremos isso.

Uma rede isolada para a nosso ambiente: `docker network create pokenode-network`

## Associando um container a uma rede

Para o redis, podemos fazer: `docker container run -d --network=pokenode-network redis`

Vamos executar o nosso container na mesma rede: `docker container run -ti --network=pokenode-network pokenode /bin/bash`

Para saber se a rede está corretamente configurada, podemos pingar o outro container `ping 18e2f6857bdb` (precisa instalar o ping).

Todavia, o nome do containter é efêmero, mudará a cada nova execução do redis. Para mitigar esse problema, podemos dar um nome ao container: `docker container run --name=db --network=pokenode-network pokenode`

`ping db` deve funcionar agora:

>root@b1097a4115d1:/# ping db
PING db (172.18.0.2) 56(84) bytes of data.
64 bytes from db.pokenode-network (172.18.0.2): icmp_seq=1 ttl=64   time=0.107 ms
64 bytes from db.pokenode-network (172.18.0.2): icmp_seq=2 ttl=64   time=0.106 ms
64 bytes from db.pokenode-network (172.18.0.2): icmp_seq=3 ttl=64   time=0.166 ms
64 bytes from db.pokenode-network (172.18.0.2): icmp_seq=4 ttl=64   time=0.102 ms

## Tornando nossa aplicação configurável

Do [12factor](https://12factor.net/pt_br/config), temos:

> Aplicações as vezes armazenam as configurações no código como constantes. Isto é uma violação do doze-fatores, o que exige uma estrita separação da configuração a partir do código. Configuração varia substancialmente entre deploys, código não.

Vamos mudar o application.yml para tornar o host do banco configurável:

```
spring:
  datasource:
    driver-class-name: org.postgresql.Driver
    url: jdbc:postgresql://${DB_HOST:localhost}/postgres
    username: postgres
  jpa:
    hibernate:
      dialect: org.hibernate.dialect.PostgresSQLDialect
      ddl-auto: create-drop

```

## Indicando o host do banco de dados

Agora podemos indicar qual o endereço do banco de dados usando a opção `-e` do comando `run`:

```
docker container run -e DB_HOST=db --network=javakihon javakihon
```

## Acessando de dentro do container

A aplicação é iniciada com sucesso, mas está acessível somente dentro do container. Podemos verificar isso executando `curl localhost:8080` (talvez precise instalar também).

Como acessar do host?

## Acessando de fora do container

Devemos indicar, no momemnto de criação da image, que o container deve aceitar conexões em uma determinada porta:

```
EXPOSE 8080
```

Como o postgres, nosso comando run também deve mapear a porta: `docker container run -e DB_HOST=db --network=javakihon -p 8080:8080 javakihon`

## Simplificando o gerenciamento com docker-compose

Até agora temos que gerenciar o container do postgres, assegurar que a rede para os containers está criada e executar o container da nossa aplicação com os paramêtros corretos.

Tudo isso pode ser simplificado usando o `docker-compose`.

## docker-compose.yml

Todo o gerenciamento de containers pode ser traduzido em um arquivo do docker-compose semelhante a esse:

```
version: '3'

services:
  app:
    image: javakihon
    build: .
    ports:
      - 8080:8080
    environment:
      - DB_HOST=db
    depends_on:
      - db
  db:
    image: postgres
```

Agora podemos usar `docker-compose up` e `docker-compose down` para iniciar e parar os containers. O docker-compose também pode ser utilizado para criar as imagens: `docker-compose build`

## Ciclo de desenvolvimento - Volumes

Nesse ponto, ainda é necessário criar uma nova imagem a cada vez que mudamos o código. Idealmente, para desenvolvimento, queremos que esteja sincronizado com as mudanças no host. Podemos fazer isso usando volumes.

Primeiro temos que indicar, na imagem, que "montaremos" um volume em `/app`:

```
VOLUME /app
```

Ao executar o container, montamos o diretório atual nesse volume:

```
app:
  image: javakihon
  build: .
  ports:
    - 8080:8080
  environment:
    - DB_HOST=db
  depends_on:
    - db
  volumes:
    - .:/app
```

Com o código sincronizado, executamos `docker-compose run --rm app bash` e então rodamos os testes de dentro do container.

## Não rodar como root

TBD

## dockerignore

TBD
