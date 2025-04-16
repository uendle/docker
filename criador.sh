#!/bin/bash

while true; do
	clear
	echo "Deseja configurar um manager ou worker ??"
	echo "Digite 1 para Manager;"
	echo "Digite 2 para worker;"
	echo "Ou qualquer outro valor para sair"

	read -p "Qual sua escolha: " escolha


	case "$escolha" in
	1)
		echo "Selecione uma das opções abaixo:"
		echo "1 para atualizar o sistema;"
		echo "2 para instalar nfs-server;"
		echo "3 para configurar o nfs;"
		echo "4 para instalar o docker;"
		echo "5 para configurar um container mysql;"
		echo "6 para fazer primeira inserção no banco;"
		echo "7 para configurar um swarm;"
		echo "8 pra configurar server web no cluster;"
		echo "9 instalar e configurar o servidor nginx;"
		echo "Ou qualquer outro para voltar ao Menu principal;"
		
		read -p "Qual serviço deseja realizar: " servico
		case "$servico" in
		1)
			#atualizar
			apt update -y
			apt upgrade -y
			continue
			;;
		2)
			#instalar nfs
			apt install nfs-common -y
			continue
			;;
		3)	
			#configurar nfs
			mkdir -p /nfs/web
			read -p "digite o IP(xxx.xxx.xxx.xxx/xx) que terao acesso ou (*)pra todos" ip
			echo "/nfs/web $ip(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
			exportfs -ra
			systemctl restart nfs-server
			exportfs -v
			continue
			;;
		4)
			#instalar o docker
			apt install docker.io -y
			continue
			;;
		5)
			#criando container mysql
			read -s -p "Digite a senha para o Root: " senharoot
			echo
			docker run -d \
			--name mysql \
			-e MYSQL_ROOT_PASSWORD="$senharoot" \
			-e MYSQL_DATABASE=banco \
			-v /nfs/db:/var/lib/mysql \
			-p 3306:3306 \
			mysql:8.0
			
			# Espera o MySQL iniciar (evita erro de conexão)
			echo "Aguardando inicialização do MySQL..."
			sleep 10

			# Executa o comando SQL dentro do container
			docker exec -i mysql mysql -uroot -p"$senharoot" -e \
  			"ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY '$senharoot'; FLUSH PRIVILEGES;"
  			echo "Configuração de acesso remoto aplicada."

			continue
			;;
		6)
			#inserir primeira tabela
			if [ -z "$senharoot" ]; then
				read -s -p "Digite a senha do root configurada anteriormente no MySQL: " senharoot
				echo
			fi
			
			docker exec -i mysql mysql -uroot -p"$senharoot" -e \
			"use banco;CREATE TABLE dados (
			AlunoID int,
			Nome varchar(50),
			Sobrenome varchar(50),
			Endereco varchar(150),
			Cidade varchar(50),
			Host varchar(50));"
			continue
			;;
		7)
    		#configura swarm
    		docker swarm init

    		# Captura o token do worker
    		token=$(docker swarm join-token worker -q)
			echo "$token" > /nfs/web/token.txt
			echo "Token do worker armazenado em /nfs/web:"
			echo "$token"

			ip_manager=$(hostname -I | awk '{print $1}')
			echo "Comando para adicionar o worker:"
			echo "docker swarm join --token $token $ip_manager:2377"


   			 continue
    		;;
    	8)
    		docker service create \
  			--name web \
 			--replicas 6 \
  			--publish 80:80 \
  			--mount type=bind,source=/nfs/web,target=/app \
  			webdevops/php-apache:alpine-php7
  			
    		continue
    		;;
    	9)
			# Solicitar os IPs para a configuração do proxy
			echo "Digite os IPs dos servidores backend (um por vez):"
			read -p "Digite o IP do primeiro servidor: " ip1
			read -p "Digite o IP do segundo servidor: " ip2
			read -p "Digite o IP do terceiro servidor: " ip3

			# Criação da pasta "proxy" e definição de permissões
			echo "Criando pasta /proxy e definindo permissões..."
			mkdir /proxy
			chmod 777 /proxy

			# Criação do arquivo nginx.conf com os IPs fornecidos
			echo "Criando arquivo nginx.conf dentro de /proxy..."
			cat <<EOF > /proxy/nginx.conf
http {
   
    upstream all {
        server $ip1:80;
        server $ip2:80;
        server $ip3:80;
    }

    server {
         listen 4500;
         location / {
              proxy_pass http://all/;
         }
    }

}

events { }
EOF

			echo "Arquivo nginx.conf criado com sucesso!"

			# Criação do Dockerfile
			echo "Criando arquivo Dockerfile..."
			cat <<EOF > /proxy/Dockerfile
FROM nginx
COPY nginx.conf /etc/nginx/nginx.conf
EOF

			echo "Arquivo Dockerfile criado com sucesso!"

			# Construção da imagem Docker com o nome "proxy"
			echo "Criando a imagem Docker com o nome 'proxy'..."
			cd /proxy
			docker build -t proxy .

			# Exibição da imagem criada
			echo "Imagens Docker disponíveis:"
			docker image ls

			# Criação do container "proxy" com a imagem gerada
			echo "Criando o container 'proxy' com a imagem 'proxy'..."
			docker run --name proxy -dti -p 4500:4500 proxy

			# Exibição do container em execução
			echo "Containers em execução:"
			docker ps

			echo "Configuração concluída com sucesso!"

    		continue
			;;
		*)
			echo "Voltando"
			continue
			;;
		esac
		;;
	
	2 )
		echo "Selecione uma das opções abaixo:"
		echo "1 para atualizar o sistema;"
		echo "2 para instalar nfs-common;"
		echo "3 para configurar o nfs;"
		echo "4 para instalar o docker;"
		echo "5 adiciona host ao closter;"
		echo "Ou qualque outro para voltar ao Menu principal;"
		
		read -p "Qual serviço deseja realizar: " servico
		case "$servico" in
		1)
			#atualizar
			apt update -y
			apt upgrade -y
			continue
			;;
		2)
			#instalar nfs
			apt install nfs-common -y
			continue
			;;
		3)
			#configurar nfs
			mkdir -p /nfs/web
			read -p "digite o IP do servidor(Manager)" ip
			echo "$ip:/nfs/web  /nfs/web  nfs  defaults,_netdev  0  0" >> /etc/fstab
			mount -a
			continue
			;;
		4)
			#instalar o docker
			apt install docker.io -y
			continue
			;;
		5)
			#adicionar ao closter
			read -p "Digite o IP do Manager: " ip
			if [ -f /nfs/web/token.txt ]; then
    			token=$(cat /nfs/web/token.txt)
   				docker swarm join --token "$token" "$ip:2377"
			else
   				 echo "Token não encontrado. Certifique-se de que o manager já foi configurado."
			fi
			continue
			;;

		*)
			echo "Voltando..."
			continue
			;;
		esac
	;;
	*)
		echo "Saindo..."
		sleep 5
		exit
		;;
	esac
done
#instale docker 
#apt install docker.io docker-compose -y

