## Clonar repositório

`git clone git@github.com:ronualdo/javakihon.git`

## Rodar testes

No diretório raiz, executar `make test`.

## Executar aplicação

No diretório raiz, executar `make run`.

> org.postgresql.util.PSQLException: Connection refused. Check that the hostname and port are correct and that the postmaster is accepting

App não conseguiu achar o banco de dados, precisamos de um.

## Executando postgres a partir de container

Pull da imagem padrão `docker image pull postgres`. Executar container `docker container run postgres`.

Se listarmos os containers `docker container ls`

| CONTAINER ID | IMAGE | COMMAND | CREATED | STATUS | PORTS | NAMES |
|--------------|-------|---------|---------|--------|-------|-------|
| 6740b6c4f3ba | postgres | "docker-entrypoint..." | 59 seconds ago | Up 57 seconds | 5432/tcp | awesome_euclid |

Agora podemos executar novamente a aplicação `make run`, mas mesmo assim ela não deve conseguir conectar ao banco. Por que?

## Portas

O ports do container mostra 5432/tcp, mas ela não deve estar mapeada para nenhuma no host.

Executar `docker container port 6740b6c4f3ba` deve retornar uma lista vazia.

Como mapear as portas? 2 opções no docker container run:

- -P: mapeia as portas para portas randomicas no host
- -p \<container-port\>:
\<host-port\>: mapeia as portas específicas

Assim, podemos exeutar `docker container run -p 5432:5432 postgres`.

O container em execução agora tem a porta mapeada para o host `docker container ls`

| CONTAINER ID | IMAGE | COMMAND | CREATED | STATUS | PORTS | NAMES |
|--------------|-------|---------|---------|--------|-------|-------|
| d4bd5134b4ba | postgres | "docker-entrypoint..." | 59 seconds ago | Up 57 seconds | 0.0.0.0:5432->5432/tcp | angry_darwin |

`docker container port d4bd5134b4ba`

> 5432/tcp -> 0.0.0.0:5432

Finalmente podemos executar `make run` e visitar http://localhost:8080/

## Executando em segundo plano

O comando `docker container run -p 5432:5432 -d postgres` executará o container em segundo plano.

## Movendo a aplicação para um container

Do que nossa aplicação precisa pra executar?

- Java
- make para executar os comandos
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

Agora podemos adicionar os pacotes necessários para o executar a aplicação:

```
RUN apt-get update && \  
apt-get install -y make openjdk-8-jdk && \  
apt-get clean
```

Novamente, `docker image build .`

| REPOSITORY | TAG | IMAGE ID | CREATED | SIZE |
|------------|-----|----------|---------|------|
| \<none\> | \<none\> | e791248e891e | About a minute ago | 487 MB |

Depender de `latest` não é uma boa prática, vamos mudar para 16.04 (versão com suporte):

```
FROM ubuntu:16.04
```

## Dando nome a nossa imagem

Podemos associar uma tag a imagem criada usando a opção `-t`:

`docker image build . -t javakioh`

| REPOSITORY | TAG | IMAGE ID | CREATED | SIZE |
|------------|-----|----------|---------|------|
| javakihon | latest | e791248e891e | About a minute ago | 487 MB |

## Tarefa make para construir imagem

Para padronizar a execução, podemos adicionar o seguinte bloco no `Makefile`

```
buildImage:  
  docker image build . -t javakioh
```

Agora podemos criar uma versão nova da imagem usando `make buildImage`.

## Usando a imagem

Vamos entrar no container pra saber se tudo foi instalado corretamente: `docker container run javakihon /bin/bash`

O `docker container run <imagem> <comando>` o comando em container baseado na imagem. A vida do container é associada diretamente ao processo do comando, assim que encerrado, o container parará.

Para manter a sessão, devemos utilizar as opções `-i` (modo interativo) e `-t` (para alocar um tty) do comando `run`.

Dessa vez, executaremos: `docker container run -ti javakihon /bin/bash`

Outros comandos interessantes: `docker container ls`, `docker start` e `docker stop`.

## Código fonte

Copiar arquivos do host para a image é feito usando o comando `COPY`:

> COPY . /app

Devemos recriar a image `make buildImage` e então podemos verificar se o código está por lá `docker container run javakihon ls /app`

## Executando testes a partir do container

Já com o código e as dependências instaladas, podemos executar os testes a partir do container: `docker container run -ti javakihon bash -c "cd app && make test"`.

## Quais outros serviços ela precisa?

Em execução, o aplicação precisa do banco de dados. Nesse caso temos 2 opções:

- Instalar e executar postgres dentro do container: Não é uma boa prática. Por que?
- Usar o container do postgres: irado!

## Network

Por padrão docker cria uma rede docker0 que é compartilhada por todos os containers. Mas não queremos isso.

Uma rede isolada para a nosso ambiente: `docker network create javakihon`

## Associando um container a uma rede

Para o postgres, podemos fazer: `docker container run -d --network=javakihon postgres`

Vamos executar o nosso container na mesma rede: `docker container run -ti --network=javakihon javakihon /bin/bash`

Para saber se a rede está corretamente configurada, podemos verificar o arquivo `/etc/hosts`:

>root@18e2f6857bdb:/# cat /etc/hosts  
127.0.0.1	localhost  
::1	localhost ip6-localhost ip6-loopback  
fe00::0	ip6-localnet  
ff00::0	ip6-mcastprefix  
ff02::1	ip6-allnodes  
ff02::2	ip6-allrouters  
172.18.0.3	18e2f6857bdb <- container

Podemos pingar o outro container `ping 18e2f6857bdb` (precisa instalar o ping).

Todavia, o nome do containter é efêmero, portando o aquivo mudará a cada nova execução do postgres. Para mitigar esse problema, podemos dar um nome ao container: `docker container run --name=db --network=javakihon postgres`

`ping db` deve funcionar agora:

>root@b1097a4115d1:/# ping db  
PING db (172.18.0.2) 56(84) bytes of data.  
64 bytes from db.javakihon (172.18.0.2): icmp_seq=1 ttl=64   time=0.107 ms  
64 bytes from db.javakihon (172.18.0.2): icmp_seq=2 ttl=64   time=0.106 ms  
64 bytes from db.javakihon (172.18.0.2): icmp_seq=3 ttl=64   time=0.166 ms  
64 bytes from db.javakihon (172.18.0.2): icmp_seq=4 ttl=64   time=0.102 ms

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

## Executando a aplicação no container

Agora podemos indicar qual o endereço do banco de dados na própria image:

```
ENV DB_HOST db
```

Também podemos adicinar um comando padrão para executá-la:

```
CMD cd /app && make run
```

## Acessando de dentro do container

A aplicação é iniciada com sucesso, mas está acessível somente dentro do container. Podemos verificar isso executando `curl localhost:8080` (talvez precise instalar também).

Como acessar do host?

## Acessando de fora do container

Devemos indicar, no momemnto de criação da image, que o container deve aceitar conexões em uma determinada porta:

```
EXPOSE 8080  
```

Como o postgres, nosso comando run também deve mapear a porta: `docker container run --network=javakihon -p 8080:8080 javakihon`

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

Agora podemos usar `docker-compose up` e `docker-compose down` para iniciar e parar os containers.

## Ciclo de desenvolvimento - Volumes

## Não rodar como root
