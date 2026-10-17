#!/bin/bash
#################### x-ui-pro v2.4.3 @ github.com/GFW4Fun ##############################################
[[ $EUID -ne 0 ]] && echo "not root!" && sudo su -
##############################INFO######################################################################
msg_ok() { echo -e "\e[1;42m $1 \e[0m";}
msg_err() { echo -e "\e[1;41m $1 \e[0m";}
msg_inf() { echo -e "\e[1;34m$1\e[0m";}
echo;msg_inf '           ___    _   _   _  '	;
msg_inf		 ' \/ __ | |  | __ |_) |_) / \ '	;
msg_inf		 ' /\    |_| _|_   |   | \ \_/ '	; echo
##################################Variables#############################################################
XUIDB="/etc/x-ui/x-ui.db";domain="";UNINSTALL="x";INSTALL="n";PNLNUM=1;CFALLOW="n";CLASH=0;CUSTOMWEBSUB=0
Pak=$(type apt &>/dev/null && echo "apt" || echo "yum")
systemctl stop x-ui
rm -rf /etc/systemd/system/x-ui.service
rm -rf /usr/local/x-ui
rm -rf /etc/x-ui
rm -rf /etc/nginx/sites-enabled/*
rm -rf /etc/nginx/sites-available/*
rm -rf /etc/nginx/stream-enabled/*


##################################generate ports and paths#############################################################
get_port() {
	echo $(( ((RANDOM<<15)|RANDOM) % 49152 + 10000 ))
}

gen_random_string() {
    local length="$1"
    head -c 4096 /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c "$length"
    echo
}
check_free() {
	local port=$1
	nc -z 127.0.0.1 $port &>/dev/null
	return $?
}

make_port() {
	while true; do
		PORT=$(get_port)
		if ! check_free $PORT; then 
			echo $PORT
			break
		fi
	done
}

sub_port=$(make_port)
panel_port=$(make_port)
web_path=$(gen_random_string 10)
sub2singbox_path=$(gen_random_string 10)
sub_path=$(gen_random_string 10)
json_path=$(gen_random_string 10)
panel_path=$(gen_random_string 10)
ws_port=$(make_port)
trojan_port=$(make_port)
ws_path=$(gen_random_string 10)
trojan_path=$(gen_random_string 10)
xhttp_path=$(gen_random_string 10)
config_username=$(gen_random_string 10)
config_password=$(gen_random_string 10)
AUTODOMAIN="n"

################################Get arguments###########################################################
while [ "$#" -gt 0 ]; do
  case "$1" in
    -auto_domain) AUTODOMAIN="$2"; shift 2;;
    -install) INSTALL="$2"; shift 2;;
    -panel) PNLNUM="$2"; shift 2;;
    -subdomain) domain="$2"; shift 2;;
    -reality_domain) reality_domain="$2"; shift 2;;
    -ONLY_CF_IP_ALLOW) CFALLOW="$2"; shift 2;;
    -websub) CUSTOMWEBSUB="$2"; shift 2;;
    -clash) CLASH="$2"; shift 2;;
    -uninstall) UNINSTALL="$2"; shift 2;;
    *) shift 1;;
  esac
done


##############################Uninstall#################################################################
UNINSTALL_XUI(){
	printf 'y\n' | x-ui uninstall
	rm -rf "/etc/x-ui/" "/usr/local/x-ui/" "/usr/bin/x-ui/"
	$Pak -y remove nginx nginx-common nginx-core nginx-full python3-certbot-nginx
	$Pak -y purge nginx nginx-common nginx-core nginx-full python3-certbot-nginx
	$Pak -y autoremove
	$Pak -y autoclean
	rm -rf "/var/www/html/" "/etc/nginx/" "/usr/share/nginx/" 
}
if [[ ${UNINSTALL} == *"y"* ]]; then
	UNINSTALL_XUI	
	clear && msg_ok "Completely Uninstalled!" && exit 1
fi


# --- get public IPv4 early (for auto-domain mode)
IP4_REGEX="^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"
IP4=$(ip route get 8.8.8.8 2>&1 | grep -Po -- 'src \K\S*')
[[ $IP4 =~ $IP4_REGEX ]] || IP4=$(curl -s ipv4.icanhazip.com | tr -d '[:space:]')


if [[ ${AUTODOMAIN} == *"y"* ]]; then
    domain="${IP4}.cdn-one.org"
    reality_domain="${IP4//./-}.cdn-one.org"
fi


##############################Domain Validations########################################################
while true; do	
	if [[ -n "$domain" ]]; then
		break
	fi
	echo -en "Enter available subdomain (sub.domain.tld): " && read domain 
done

domain=$(echo "$domain" 2>&1 | tr -d '[:space:]' )
SubDomain=$(echo "$domain" 2>&1 | sed 's/^[^ ]* \|\..*//g')
MainDomain=$(echo "$domain" 2>&1 | sed 's/.*\.\([^.]*\..*\)$/\1/')

if [[ "${SubDomain}.${MainDomain}" != "${domain}" ]] ; then
	MainDomain=${domain}
fi

while true; do	
	if [[ -n "$reality_domain" ]]; then
		break
	fi
	echo -en "Enter available subdomain for REALITY (sub.domain.tld): " && read reality_domain 
done

reality_domain=$(echo "$reality_domain" 2>&1 | tr -d '[:space:]' )
RealitySubDomain=$(echo "$reality_domain" 2>&1 | sed 's/^[^ ]* \|\..*//g')
RealityMainDomain=$(echo "$reality_domain" 2>&1 | sed 's/.*\.\([^.]*\..*\)$/\1/')

if [[ "${RealitySubDomain}.${RealityMainDomain}" != "${reality_domain}" ]] ; then
	RealityMainDomain=${reality_domain}
fi

###############################Install Packages#########################################################
ufw disable
if [[ ${INSTALL} == *"y"* ]]; then

         version=$(grep -oP '(?<=VERSION_ID=")[0-9]+' /etc/os-release)

        if [[ "$version" == "20" || "$version" == "22" || "$version" == "24" ]]; then
              echo "Версия системы: Ubuntu $version"
        fi

	$Pak -y update

	$Pak -y install curl wget jq bash sudo nginx-full certbot python3-certbot-nginx sqlite3 ufw psmisc

	systemctl daemon-reload && systemctl enable --now nginx
fi
systemctl stop nginx 
fuser -k 80/tcp 80/udp 443/tcp 443/udp 2>/dev/null
##################################GET SERVER IPv4-6#####################################################
IP4_REGEX="^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"
IP6_REGEX="([a-f0-9:]+:+)+[a-f0-9]+"
IP4=$(ip route get 8.8.8.8 2>&1 | grep -Po -- 'src \K\S*')
IP6=$(ip route get 2620:fe::fe 2>&1 | grep -Po -- 'src \K\S*')
[[ $IP4 =~ $IP4_REGEX ]] || IP4=$(curl -s ipv4.icanhazip.com);
[[ $IP6 =~ $IP6_REGEX ]] || IP6=$(curl -s ipv6.icanhazip.com);
##############################Install SSL###############################################################

resolve_to_ip () {
    local host="$1"
    local a
    a=$(getent ahostsv4 "$host" 2>/dev/null | awk 'NR==1{print $1}')
    [[ -n "$a" ]] && [[ "$a" == "$IP4" ]]
}

if [[ ${AUTODOMAIN} == *"y"* ]]; then
    if ! resolve_to_ip "$domain"; then
        msg_err "Auto-domain $domain does not resolve to this server IP ($IP4). Fix DNS/service and retry."
        exit 1
    fi
    if ! resolve_to_ip "$reality_domain"; then
        msg_err "Auto-domain $reality_domain does not resolve to this server IP ($IP4). Fix DNS/service and retry."
        exit 1
    fi
fi


certbot certonly --standalone --non-interactive --agree-tos --register-unsafely-without-email -d "$domain"
if [[ ! -d "/etc/letsencrypt/live/${domain}/" ]]; then
 	systemctl start nginx >/dev/null 2>&1
	msg_err "$domain SSL could not be generated! Check Domain/IP Or Enter new domain!" && exit 1
fi

certbot certonly --standalone --non-interactive --agree-tos --register-unsafely-without-email -d "$reality_domain"
if [[ ! -d "/etc/letsencrypt/live/${reality_domain}/" ]]; then
 	systemctl start nginx >/dev/null 2>&1
	msg_err "$reality_domain SSL could not be generated! Check Domain/IP Or Enter new domain!" && exit 1
fi

chmod 755 /etc/letsencrypt /etc/letsencrypt/live /etc/letsencrypt/archive /etc/letsencrypt/live/* /etc/letsencrypt/archive/* 2>/dev/null || true
chmod 755 /root 2>/dev/null || true

###################################Get Installed XUI Port/Path##########################################
if [[ -f $XUIDB ]]; then
	XUIPORT=$(sqlite3 -list $XUIDB 'SELECT "value" FROM settings WHERE "key"="webPort" LIMIT 1;' 2>&1)
	XUIPATH=$(sqlite3 -list $XUIDB 'SELECT "value" FROM settings WHERE "key"="webBasePath" LIMIT 1;' 2>&1)
if [[ $XUIPORT -gt 0 && $XUIPORT != "54321" && $XUIPORT != "2053" ]] && [[ ${#XUIPORT} -gt 4 ]]; then
	RNDSTR=$(echo "$XUIPATH" 2>&1 | tr -d '/')
	PORT=$XUIPORT
	sqlite3 $XUIDB <<EOF
	DELETE FROM "settings" WHERE ( "key"="webCertFile" ) OR ( "key"="webKeyFile" ); 
	INSERT INTO "settings" ("key", "value") VALUES ("webCertFile",  "");
	INSERT INTO "settings" ("key", "value") VALUES ("webKeyFile", "");
EOF
fi
fi
#################################Nginx Config###########################################################
mkdir -p /root/cert/${domain}
chmod 755 /root/cert 2>/dev/null || true

ln -sf /etc/letsencrypt/live/${domain}/fullchain.pem /root/cert/${domain}/fullchain.pem
ln -sf /etc/letsencrypt/live/${domain}/privkey.pem /root/cert/${domain}/privkey.pem

mkdir -p /etc/nginx/stream-enabled
cat > "/etc/nginx/stream-enabled/stream.conf" << EOF
map \$ssl_preread_server_name \$sni_name {
    hostnames;
    ${reality_domain}      xray;
    ${domain}           www;
    default              xray;
}

upstream xray {
    server 127.0.0.1:8443;
}

upstream www {
    server 127.0.0.1:7443;
}

server {
    proxy_protocol on;
    listen          443;
	listen         [::]:443;
    proxy_pass      \$sni_name;
    ssl_preread     on;
}

EOF

grep -xqFR "stream { include /etc/nginx/stream-enabled/*.conf; }" /etc/nginx/* || echo "stream { include /etc/nginx/stream-enabled/*.conf; }" >> /etc/nginx/nginx.conf
if ! ls /etc/nginx/modules-enabled/*stream* &>/dev/null && ! grep -qF "ngx_stream_module" /etc/nginx/nginx.conf; then
    [[ -f /usr/lib/nginx/modules/ngx_stream_module.so ]] && sed -i '1s|^|load_module /usr/lib/nginx/modules/ngx_stream_module.so;\n|' /etc/nginx/nginx.conf
fi
if ! ls /etc/nginx/modules-enabled/*geoip2* &>/dev/null && ! grep -qF "ngx_stream_geoip2_module" /etc/nginx/nginx.conf; then
    [[ -f /usr/lib/nginx/modules/ngx_stream_geoip2_module.so ]] && sed -i '2s|^|load_module /usr/lib/nginx/modules/ngx_stream_geoip2_module.so;\n|' /etc/nginx/nginx.conf
fi
grep -xqFR "worker_rlimit_nofile 16384;" /etc/nginx/* || echo "worker_rlimit_nofile 16384;" >> /etc/nginx/nginx.conf
sed -i "/worker_connections/c\worker_connections 4096;" /etc/nginx/nginx.conf
cat > "/etc/nginx/sites-available/80.conf" << EOF
server {
    listen 80;
    server_name ${domain} ${reality_domain};
    return 301 https://\$host\$request_uri;
}
EOF


cat > "/etc/nginx/sites-available/${domain}" << EOF
server {
	server_tokens off;
	server_name ${domain};
	listen 7443 ssl http2 proxy_protocol;
	listen [::]:7443 ssl http2 proxy_protocol;
	index index.html index.htm index.php index.nginx-debian.html;
	root /var/www/html/;
	ssl_protocols TLSv1.2 TLSv1.3;
	ssl_ciphers HIGH:!aNULL:!eNULL:!MD5:!DES:!RC4:!ADH:!SSLv3:!EXP:!PSK:!DSS;
	ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
	if (\$host !~* ^(.+\.)?${domain}\$ ){return 444;}
	if (\$scheme ~* https) {set \$safe 1;}
	if (\$ssl_server_name !~* ^(.+\.)?${domain}\$ ) {set \$safe "\${safe}0"; }
	if (\$safe = 10){return 444;}
	if (\$request_uri ~ "(\"|'|\`|~|,|:|;|%|\\$|&&|\?\?|0x00|0X00|\||\\|\{|\}|\[|\]|<|>|\.\.\.|\.\.\/|\/\/\/)"){set \$hack 1;}
	error_page 400 401 402 403 500 501 502 503 504 =404 /404;
	proxy_intercept_errors on;
	#X-UI Admin Panel
	location /${panel_path}/ {
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;

        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;

        proxy_pass https://127.0.0.1:${panel_port};
		break;
	}
        location /${panel_path} {
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;

        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;

        proxy_pass https://127.0.0.1:${panel_port};
		break;
	}
	include /etc/nginx/snippets/includes.conf;

}
EOF

cat > "/etc/nginx/snippets/includes.conf" << EOF
  	#sub2sing-box
	location /${sub2singbox_path}/ {
		proxy_redirect off;
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_pass http://127.0.0.1:8080/;
		}
    # Path to open clash.yaml and generate YAML
    location ~ ^/${web_path}/clashmeta/(.+)$ {
        default_type text/plain;
        ssi on;
        ssi_types text/plain;
        set \$subid \$1;
        root /var/www/subpage;
        try_files /clash.yaml =404;
    }
    # web
    location ~ ^/${web_path} {
        root /var/www/subpage;
        index index.html;
        try_files \$uri \$uri/ /index.html =404;
    }
 	#Subscription Path (simple/encode)
        location /${sub_path} {
                if (\$hack = 1) {return 404;}
                proxy_redirect off;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_pass https://127.0.0.1:${sub_port};
                break;
        }
	location /${sub_path}/ {
                if (\$hack = 1) {return 404;}
                proxy_redirect off;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_pass https://127.0.0.1:${sub_port};
                break;
        }
	location /assets/ {
                if (\$hack = 1) {return 404;}
                proxy_redirect off;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_pass https://127.0.0.1:${sub_port};
                break;
        }
	location /assets {
                if (\$hack = 1) {return 404;}
                proxy_redirect off;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_pass https://127.0.0.1:${sub_port};
                break;
        }
	#Subscription Path (json/fragment)
        location /${json_path} {
                if (\$hack = 1) {return 404;}
                proxy_redirect off;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_pass https://127.0.0.1:${sub_port};
                break;
        }
	location /${json_path}/ {
                if (\$hack = 1) {return 404;}
                proxy_redirect off;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_pass https://127.0.0.1:${sub_port};
                break;
        }
        #XHTTP
        location /${xhttp_path} {
          grpc_pass grpc://unix:/dev/shm/uds2023.sock;
          grpc_buffer_size         16k;
          grpc_socket_keepalive    on;
          grpc_read_timeout        1h;
          grpc_send_timeout        1h;
          grpc_set_header Connection         "";
          grpc_set_header X-Forwarded-For    \$proxy_add_x_forwarded_for;
          grpc_set_header X-Forwarded-Proto  \$scheme;
          grpc_set_header X-Forwarded-Port   \$server_port;
          grpc_set_header Host               \$host;
          grpc_set_header X-Forwarded-Host   \$host;
          }
 	#Xray Config Path
	location ~ ^/(?<fwdport>\d+)/(?<fwdpath>.*)\$ {
		if (\$hack = 1) {return 404;}
		client_max_body_size 0;
		client_body_timeout 1d;
		grpc_read_timeout 1d;
		grpc_socket_keepalive on;
		proxy_read_timeout 1d;
		proxy_http_version 1.1;
		proxy_buffering off;
		proxy_request_buffering off;
		proxy_socket_keepalive on;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection "upgrade";
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		if (\$content_type ~* "GRPC") {
			grpc_pass grpc://127.0.0.1:\$fwdport\$is_args\$args;
			break;
		}
		if (\$http_upgrade ~* "(WEBSOCKET|WS)") {
			proxy_pass http://127.0.0.1:\$fwdport\$is_args\$args;
			break;
	        }
		if (\$request_method ~* ^(PUT|POST|GET)\$) {
			proxy_pass http://127.0.0.1:\$fwdport\$is_args\$args;
			break;
		}
	}
	location / { try_files \$uri \$uri/ =404; }
EOF

cat > "/etc/nginx/sites-available/${reality_domain}" << EOF
server {
	server_tokens off;
	server_name ${reality_domain};
	listen 9443 ssl http2;
	listen [::]:9443 ssl http2;
	index index.html index.htm index.php index.nginx-debian.html;
	root /var/www/html/;
	ssl_protocols TLSv1.2 TLSv1.3;
	ssl_ciphers HIGH:!aNULL:!eNULL:!MD5:!DES:!RC4:!ADH:!SSLv3:!EXP:!PSK:!DSS;
	ssl_certificate /etc/letsencrypt/live/$reality_domain/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/$reality_domain/privkey.pem;
	if (\$host !~* ^(.+\.)?${reality_domain}\$ ){return 444;}
	if (\$scheme ~* https) {set \$safe 1;}
	if (\$ssl_server_name !~* ^(.+\.)?${reality_domain}\$ ) {set \$safe "\${safe}0"; }
	if (\$safe = 10){return 444;}
	if (\$request_uri ~ "(\"|'|\`|~|,|:|;|%|\\$|&&|\?\?|0x00|0X00|\||\\|\{|\}|\[|\]|<|>|\.\.\.|\.\.\/|\/\/\/)"){set \$hack 1;}
	error_page 400 401 402 403 500 501 502 503 504 =404 /404;
	proxy_intercept_errors on;
	#X-UI Admin Panel
	location /${panel_path}/ {
		proxy_redirect off;
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_pass https://127.0.0.1:${panel_port};
		break;
	}
        location /$panel_path {
		proxy_redirect off;
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_pass https://127.0.0.1:${panel_port};
		break;
	}
include /etc/nginx/snippets/includes.conf;
}
EOF
##################################Check Nginx status####################################################
if [[ -f "/etc/nginx/sites-available/${domain}" ]]; then
	unlink "/etc/nginx/sites-enabled/default" >/dev/null 2>&1
	rm -f "/etc/nginx/sites-enabled/default" "/etc/nginx/sites-available/default"
	ln -sf "/etc/nginx/sites-available/${domain}" "/etc/nginx/sites-enabled/" 2>/dev/null
    ln -sf "/etc/nginx/sites-available/${reality_domain}" "/etc/nginx/sites-enabled/" 2>/dev/null
	ln -sf "/etc/nginx/sites-available/80.conf" "/etc/nginx/sites-enabled/" 2>/dev/null
else
	msg_err "${domain} nginx config not exist!" && exit 1
fi

if [[ $(nginx -t 2>&1 | grep -o 'successful') != "successful" ]]; then
    msg_err "nginx config is not ok!" && exit 1
else
	systemctl start nginx 
fi


##############################generate uri's###########################################################
sub_uri=https://${domain}/${sub_path}/
json_uri=https://${domain}/${web_path}?name=
##############################generate keys###########################################################
shor=($(openssl rand -hex 8) $(openssl rand -hex 8) $(openssl rand -hex 8) $(openssl rand -hex 8) $(openssl rand -hex 8) $(openssl rand -hex 8) $(openssl rand -hex 8) $(openssl rand -hex 8))

########################################Update X-UI Port/Path for first INSTALL#########################
UPDATE_XUIDB(){
if [[ -f $XUIDB ]]; then
        x-ui stop
        output=$(/usr/local/x-ui/bin/xray-linux-amd64 x25519)

        private_key=$(echo "$output" | grep "^PrivateKey:" | awk '{print $2}')
        public_key=$(echo "$output" | grep "^Password" | awk '{print $3}')

        client_id=$(/usr/local/x-ui/bin/xray-linux-amd64 uuid)
        client_id2=$(/usr/local/x-ui/bin/xray-linux-amd64 uuid)
        client_id3=$(/usr/local/x-ui/bin/xray-linux-amd64 uuid)
	trojan_pass=$(gen_random_string 10)
        emoji_flag=$(LC_ALL=en_US.UTF-8 curl -s https://ipwho.is/ | jq -r '.flag.emoji')
       	sqlite3 $XUIDB <<EOF
             INSERT INTO "settings" ("key", "value") VALUES ("subPort",  '${sub_port}');
	     INSERT INTO "settings" ("key", "value") VALUES ("subPath",  '/${sub_path}/');
	     INSERT INTO "settings" ("key", "value") VALUES ("subURI",  '${sub_uri}');
             INSERT INTO "settings" ("key", "value") VALUES ("subJsonPath",  '${json_path}');
	     INSERT INTO "settings" ("key", "value") VALUES ("subJsonURI",  '${json_uri}');
		 INSERT INTO "settings" ("key", "value") VALUES ("subClashEnable",  'false');
		 INSERT INTO "settings" ("key", "value") VALUES ("subEnableRouting",  'false');
             INSERT INTO "settings" ("key", "value") VALUES ("subEnable",  'true');
             INSERT INTO "settings" ("key", "value") VALUES ("webListen",  '');
	     INSERT INTO "settings" ("key", "value") VALUES ("webDomain",  '');
             INSERT INTO "settings" ("key", "value") VALUES ("webCertFile",  '');
	     INSERT INTO "settings" ("key", "value") VALUES ("webKeyFile",  '');
      	     INSERT INTO "settings" ("key", "value") VALUES ("sessionMaxAge",  '60');
             INSERT INTO "settings" ("key", "value") VALUES ("pageSize",  '50');
             INSERT INTO "settings" ("key", "value") VALUES ("expireDiff",  '0');
             INSERT INTO "settings" ("key", "value") VALUES ("trafficDiff",  '0');
             INSERT INTO "settings" ("key", "value") VALUES ("remarkModel",  '-ieo');
             INSERT INTO "settings" ("key", "value") VALUES ("tgBotEnable",  'false');
             INSERT INTO "settings" ("key", "value") VALUES ("tgBotToken",  '');
             INSERT INTO "settings" ("key", "value") VALUES ("tgBotProxy",  '');
             INSERT INTO "settings" ("key", "value") VALUES ("tgBotAPIServer",  '');
	     INSERT INTO "settings" ("key", "value") VALUES ("tgBotChatId",  '');
             INSERT INTO "settings" ("key", "value") VALUES ("tgRunTime",  '@daily');
	     INSERT INTO "settings" ("key", "value") VALUES ("tgBotBackup",  'false');
             INSERT INTO "settings" ("key", "value") VALUES ("tgBotLoginNotify",  'true');
	     INSERT INTO "settings" ("key", "value") VALUES ("tgCpu",  '80');
             INSERT INTO "settings" ("key", "value") VALUES ("tgLang",  'en-US');
	     INSERT INTO "settings" ("key", "value") VALUES ("timeLocation",  'Europe/Moscow');
             INSERT INTO "settings" ("key", "value") VALUES ("secretEnable",  'false');
	     INSERT INTO "settings" ("key", "value") VALUES ("subDomain",  '');
             INSERT INTO "settings" ("key", "value") VALUES ("subCertFile",  '');
	     INSERT INTO "settings" ("key", "value") VALUES ("subKeyFile",  '');
             INSERT INTO "settings" ("key", "value") VALUES ("subUpdates",  '12');
	     INSERT INTO "settings" ("key", "value") VALUES ("subEncrypt",  'true');
             INSERT INTO "settings" ("key", "value") VALUES ("subShowInfo",  'true');
	     INSERT INTO "settings" ("key", "value") VALUES ("subJsonFragment",  '');
             INSERT INTO "settings" ("key", "value") VALUES ("subJsonNoises",  '');
	     INSERT INTO "settings" ("key", "value") VALUES ("subJsonMux",  '');
             INSERT INTO "settings" ("key", "value") VALUES ("subJsonRules",  '');
	     INSERT INTO "settings" ("key", "value") VALUES ("datepicker",  'gregorian');
             INSERT INTO "client_traffics" ("inbound_id","enable","email","up","down","expiry_time","total","reset") VALUES ('1','1','first','0','0','0','0','0');
	     INSERT INTO "client_traffics" ("inbound_id","enable","email","up","down","expiry_time","total","reset") VALUES ('2','1','first_1','0','0','0','0','0');
		   INSERT INTO "client_traffics" ("inbound_id","enable","email","up","down","expiry_time","total","reset") VALUES ('3','1','firstX','0','0','0','0','0');
	     INSERT INTO "client_traffics" ("inbound_id","enable","email","up","down","expiry_time","total","reset") VALUES ('4','1','firstT','0','0','0','0','0');
             INSERT INTO "inbounds" ("user_id","up","down","total","remark","enable","expiry_time","listen","port","protocol","settings","stream_settings","tag","sniffing") VALUES ( 
             '1',
	     '0',
             '0',
	     '0',
             '${emoji_flag} reality',
	     '1',
             '0',
	     '',
             '8443',
	     'vless',
             '{\n\t     \"clients\": [\n    {\n      \"id\": \"${client_id}\",\n      \"flow\": \"xtls-rprx-vision\",\n      \"email\": \"first\",\n      \"limitIp\": 0,\n      \"totalGB\": 0,\n      \"expiryTime\": 0,\n      \"enable\": true,\n      \"tgId\": \"\",\n      \"subId\": \"first\",\n      \"reset\": 0,\n      \"created_at\": 1756726925000,\n      \"updated_at\": 1756726925000\n\n    }\n  ],\n  \"decryption\": \"none\",\n  \"fallbacks\": []\n}',
	     '{\n  \"network\": \"tcp\",\n  \"security\": \"reality\",\n  \"externalProxy\": [\n    {\n      \"forceTls\": \"same\",\n      \"dest\": \"${domain}\",\n      \"port\": 443,\n      \"remark\": \"\"\n    }\n  ],\n  \"realitySettings\": {\n    \"show\": false,\n    \"xver\": 0,\n    \"target\": \"127.0.0.1:9443\",\n    \"serverNames\": [\n      \"$reality_domain\"\n    ],\n    \"privateKey\": \"${private_key}\",\n    \"minClient\": \"\",\n    \"maxClient\": \"\",\n    \"maxTimediff\": 0,\n    \"shortIds\": [\n      \"${shor[0]}\",\n      \"${shor[1]}\",\n      \"${shor[2]}\",\n      \"${shor[3]}\",\n      \"${shor[4]}\",\n      \"${shor[5]}\",\n      \"${shor[6]}\",\n      \"${shor[7]}\"\n    ],\n    \"settings\": {\n      \"publicKey\": \"${public_key}\",\n      \"fingerprint\": \"chrome\",\n      \"serverName\": \"\",\n      \"spiderX\": \"/\"\n    }\n  },\n  \"tcpSettings\": {\n    \"acceptProxyProtocol\": true,\n    \"header\": {\n      \"type\": \"none\"\n    }\n  }\n}',
             'inbound-8443',
	     '{\n  \"enabled\": false,\n  \"destOverride\": [\n    \"http\",\n    \"tls\",\n    \"quic\",\n    \"fakedns\"\n  ],\n  \"metadataOnly\": false,\n  \"routeOnly\": false\n}'
	     );\n      INSERT INTO \"inbounds\" (\"user_id\",\"up\",\"down\",\"total\",\"remark\",\"enable\",\"expiry_time\",\"listen\",\"port\",\"protocol\",\"settings\",\"stream_settings\",\"tag\",\"sniffing\") VALUES ( \n             '1',\n	     '0',\n             '0',\n	     '0',\n             '${emoji_flag} ws',\n	     '1',\n             '0',\n	     '',\n             '${ws_port}',\n	     'vless',\n             '{\n  \"clients\": [\n    {\n      \"id\": \"${client_id2}\",\n      \"flow\": \"\",\n      \"email\": \"first_1\",\n      \"limitIp\": 0,\n      \"totalGB\": 0,\n      \"expiryTime\": 0,\n      \"enable\": true,\n      \"tgId\": \"\",\n      \"subId\": \"first\",\n      \"reset\": 0,\n      \"created_at\": 1756726925000,\n      \"updated_at\": 1756726925000\n\n    }\n  ],\n  \"decryption\": \"none\",\n  \"fallbacks\": []\n}','{\n  \"network\": \"ws\",\n  \"security\": \"none\",\n  \"externalProxy\": [\n    {\n      \"forceTls\": \"tls\",\n      \"dest\": \"${domain}\",\n      \"port\": 443,\n      \"remark\": \"\"\n    }\n  ],\n  \"wsSettings\": {\n    \"acceptProxyProtocol\": false,\n    \"path\": \"/${ws_port}/${ws_path}\",\n    \"host\": \"${domain}\",\n    \"headers\": {}\n  }\n}',\n             'inbound-${ws_port}',\n\t     '{\n  \"enabled\": false,\n  \"destOverride\": [\n    \"http\",\n    \"tls\",\n    \"quic\",\n    \"fakedns\"\n  ],\n  \"metadataOnly\": false,\n  \"routeOnly\": false\n}'\n\t     );\n      INSERT INTO \"inbounds\" (\"user_id\",\"up\",\"down\",\"total\",\"remark\",\"enable\",\"expiry_time\",\"listen\",\"port\",\"protocol\",\"settings\",\"stream_settings\",\"tag\",\"sniffing\") VALUES ( \n             '1',\n	     '0',\n             '0',\n	     '0',\n             '${emoji_flag} xhttp',\n	     '0',\n             '0',\n	     '/dev/shm/uds2023.sock,0666',\n             '0',\n	     'vless',\n             '{\n  \"clients\": [\n    {\n      \"id\": \"${client_id3}\",\n      \"flow\": \"\",\n      \"email\": \"firstX\",\n      \"limitIp\": 0,\n      \"totalGB\": 0,\n      \"expiryTime\": 0,\n      \"enable\": true,\n      \"tgId\": \"\",\n      \"subId\": \"first\",\n      \"reset\": 0,\n	  \"created_at\": 1756726925000,\n      \"updated_at\": 1756726925000\n    }\n  ],\n  \"decryption\": \"none\",\n  \"fallbacks\": []\n}','{\n  \"network\": \"xhttp\",\n  \"security\": \"none\",\n  \"externalProxy\": [\n    {\n      \"forceTls\": \"tls\",\n      \"dest\": \"${domain}\",\n      \"port\": 443,\n      \"remark\": \"\"\n    }\n  ],\n  \"xhttpSettings\": {\n    \"path\": \"/${xhttp_path}\",\n    \"host\": \"${domain}\",\n    \"headers\": {},\n    \"scMaxBufferedPosts\": 30,\n    \"scMaxEachPostBytes\": \"1000000\",\n    \"noSSEHeader\": false,\n    \"xPaddingBytes\": \"100-1000\",\n    \"mode\": \"packet-up\"\n  },\n  \"sockopt\": {\n    \"acceptProxyProtocol\": false,\n    \"tcpFastOpen\": true,\n    \"mark\": 0,\n    \"tproxy\": \"off\",\n    \"tcpMptcp\": true,\n    \"tcpNoDelay\": true,\n    \"domainStrategy\": \"UseIP\",\n    \"tcpMaxSeg\": 1440,\n    \"dialerProxy\": \"\",\n    \"tcpKeepAliveInterval\": 0,\n    \"tcpKeepAliveIdle\": 300,\n    \"tcpUserTimeout\": 10000,\n    \"tcpcongestion\": \"bbr\",\n    \"V6Only\": false,\n    \"tcpWindowClamp\": 600,\n    \"interface\": \"\"\n  }\n}',\n             'inbound-/dev/shm/uds2023.sock,0666:0|',\n\t     '{\n  \"enabled\": true,\n  \"destOverride\": [\n    \"http\",\n    \"tls\",\n    \"quic\",\n    \"fakedns\"\n  ],\n  \"metadataOnly\": false,\n  \"routeOnly\": false\n}'\n\t     );\n	INSERT INTO \"inbounds\" (\"user_id\",\"up\",\"down\",\"total\",\"remark\",\"enable\",\"expiry_time\",\"listen\",\"port\",\"protocol\",\"settings\",\"stream_settings\",\"tag\",\"sniffing\") VALUES ( \n\t     '1',\n\t     '0',\n         '0',\n\t     '0',\n         '${emoji_flag} trojan-grpc',\n\t     '1',\n         '0',\n\t\t '',\n\t\t '${trojan_port}',\n\t\t 'trojan',\n\t\t '{\n  \"clients\": [\n    {\n      \"comment\": \"\",\n      \"created_at\": 1756726925000,\n      \"email\": \"firstT\",\n      \"enable\": true,\n      \"expiryTime\": 0,\n      \"limitIp\": 0,\n      \"password\": \"${trojan_pass}\",\n      \"reset\": 0,\n      \"subId\": \"first\",\n      \"tgId\": 0,\n      \"totalGB\": 0,\n      \"updated_at\": 1756726925000\n    }\n  ],\n  \"fallbacks\": []\n}',\n'{\n  \"network\": \"grpc\",\n  \"security\": \"none\",\n  \"externalProxy\": [\n    {\n      \"forceTls\": \"tls\",\n      \"dest\": \"${domain}\",\n      \"port\": 443,\n      \"remark\": \"\"\n    }\n  ],\n  \"grpcSettings\": {\n    \"serviceName\": \"/${trojan_port}/${trojan_path}\",\n    \"authority\": \"${domain}\",\n    \"multiMode\": false\n  }\n}',\n'inbound-${trojan_port}',\n'{\n  \"enabled\": false,\n  \"destOverride\": [\n    \"http\",\n    \"tls\",\n    \"quic\",\n    \"fakedns\"\n  ],\n  \"metadataOnly\": false,\n  \"routeOnly\": false\n}'\n\t);\nEOF\n/usr/local/x-ui/x-ui setting -username \"${config_username}\" -password \"${config_password}\" -port \"${panel_port}\" -webBasePath \"${panel_path}\"\n/usr/local/x-ui/x-ui cert -webCert \"/root/cert/${domain}/fullchain.pem\" -webCertKey \"/root/cert/${domain}/privkey.pem\"\nx-ui start\nelse\n\tmsg_err \"x-ui.db file not exist! Maybe x-ui isn't installed.\" && exit 1;\nfi\n}\narch() {\n    case \"$(uname -m)\" in\n        x86_64 | x64 | amd64) echo 'amd64' ;;\n        i*86 | x86) echo '386' ;;\n        armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;\n        armv7* | armv7 | arm) echo 'armv7' ;;\n        armv6* | armv6) echo 'armv6' ;;\n        armv5* | armv5) echo 'armv5' ;;\n        s390x) echo 's390x' ;;\n        *) echo -e \"${green}Unsupported CPU architecture! ${plain}\" && rm -f install.sh && exit 1 ;;\n    esac\n}\n\nconfig_after_install() {\n            /usr/local/x-ui/x-ui setting -username \"asdfasdf\" -password \"asdfasdf\" -port \"2096\" -webBasePath \"asdfasdf\"    \n            /usr/local/x-ui/x-ui migrate\n}\n\ninstall_panel() {\napt-get update && apt-get install -y -q wget curl tar tzdata\n    cd /usr/local/\n    \n    # Download resources\n    if [ $# == 0 ]; then\n        tag_version=$(curl -Ls \"https://api.github.com/repos/MHSanaei/3x-ui/releases/latest\" | grep '\"tag_name\":' | sed -E 's/.*\"([^\"]+)\".*/\\1/')\n        if [[ ! -n \"$tag_version\" ]]; then\n            echo -e \"${yellow}Trying to fetch version with IPv4...${plain}\"\n            tag_version=$(curl -4 -Ls \"https://api.github.com/repos/MHSanaei/3x-ui/releases/latest\" | grep '\"tag_name\":' | sed -E 's/.*\"([^\"]+)\".*/\\1/')\n            if [[ ! -n \"$tag_version\" ]]; then\n                echo -e \"${red}Failed to fetch x-ui version, it may be due to GitHub API restrictions, please try it later${plain}\"\n                exit 1\n            fi\n        fi\n        echo -e \"Got x-ui latest version: ${tag_version}, beginning the installation...\"\n        wget -N -O /usr/local/x-ui-linux-$(arch).tar.gz https://github.com/MHSanaei/3x-ui/releases/download/v2.9.4/x-ui-linux-$(arch).tar.gz\n        if [[ $? -ne 0 ]]; then\n            echo -e \"${red}Downloading x-ui failed, please be sure that your server can access GitHub ${plain}\"\n            exit 1\n        fi\n    else\n        tag_version=$1\n        tag_version_numeric=${tag_version#v}\n        min_version=\"2.3.5\"\n        \n        if [[ \"$(printf '%s\\n' \"$min_version\" \"$tag_version_numeric\" | sort -V | head -n1)\" != \"$min_version\" ]]; then\n            echo -e \"${red}Please use a newer version (at least v2.3.5). Exiting installation.${plain}\"\n            exit 1\n        fi\n        \n        url=\"https://github.com/MHSanaei/3x-ui/releases/download/v2.9.4/x-ui-linux-$(arch).tar.gz\"\n        echo -e \"Beginning to install x-ui $1\"\n        wget -N -O /usr/local/x-ui-linux-$(arch).tar.gz ${url}\n        if [[ $? -ne 0 ]]; then\n            echo -e \"${red}Download x-ui $1 failed, please check if the version exists ${plain}\"\n            exit 1\n        fi\n    fi\n    wget -O /usr/bin/x-ui-temp https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.sh\n    if [[ $? -ne 0 ]]; then\n        echo -e \"${red}Failed to download x-ui.sh${plain}\"\n        exit 1\n    fi\n    \n    # Stop x-ui service and remove old resources\n    if [[ -e /usr/local/x-ui/ ]]; then\n        if [[ $release == \"alpine\" ]]; then\n            rc-service x-ui stop\n        else\n            systemctl stop x-ui\n        fi\n        rm /usr/local/x-ui/ -rf\n    fi\n    \n    # Extract resources and set permissions\n    tar zxvf x-ui-linux-$(arch).tar.gz\n    rm x-ui-linux-$(arch).tar.gz -f\n    \n    cd x-ui\n    chmod +x x-ui\n    chmod +x x-ui.sh\n    \n    # Check the system's architecture and rename the file accordingly\n    if [[ $(arch) == \"armv5\" || $(arch) == \"armv6\" || $(arch) == \"armv7\" ]]; then\n        mv bin/xray-linux-$(arch) bin/xray-linux-arm\n        chmod +x bin/xray-linux-arm\n    fi\n    chmod +x x-ui bin/xray-linux-$(arch)\n    \n    # Update x-ui cli and se set permission\n    mv -f /usr/bin/x-ui-temp /usr/bin/x-ui\n    chmod +x /usr/bin/x-ui\n	config_after_install\n    \n    if [[ $release == \"alpine\" ]]; then\n        wget --inet4-only -O /etc/init.d/x-ui https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.rc\n        if [[ $? -ne 0 ]]; then\n            echo -e \"${red}Failed to download x-ui.rc${plain}\"\n            exit 1\n        fi\n        chmod +x /etc/init.d/x-ui\n        rc-update add x-ui\n        rc-service x-ui start\n    else\n        cp -f x-ui.service.debian /etc/systemd/system/x-ui.service\n        systemctl daemon-reload\n        systemctl enable x-ui\n        systemctl start x-ui\n    fi\n    \n    echo -e \"${green}x-ui ${tag_version}${plain} installation finished, it is running now...\"\n    echo -e \"\"\n}\n###################################Install X-UI#########################################################\nif systemctl is-active --quiet x-ui; then\n	x-ui restart\nelse\n    install_panel	\n	UPDATE_XUIDB\n	if ! systemctl is-enabled --quiet x-ui; then\n		systemctl daemon-reload && systemctl enable x-ui.service\n	fi\n	x-ui restart\nfi\n\n######################enable bbr and tune system########################################################\napt-get install -yqq --no-install-recommends ca-certificates\necho \"net.core.default_qdisc=fq\" | tee -a /etc/sysctl.conf\necho \"net.ipv4.tcp_congestion_control=bbr\" | tee -a /etc/sysctl.conf\necho \"fs.file-max=2097152\" | tee -a /etc/sysctl.conf\necho \"net.ipv4.tcp_timestamps = 1\" | tee -a /etc/sysctl.conf\necho \"net.ipv4.tcp_sack = 1\" | tee -a /etc/sysctl.conf\necho \"net.ipv4.tcp_window_scaling = 1\" | tee -a /etc/sysctl.conf\necho \"net.core.rmem_max = 16777216\" | tee -a /etc/sysctl.conf\necho \"net.core.wmem_max = 16777216\" | tee -a /etc/sysctl.conf\necho \"net.ipv4.tcp_rmem = 4096 87380 16777216\" | tee -a /etc/sysctl.conf\necho \"net.ipv4.tcp_wmem = 4096 65536 16777216\" | tee -a /etc/sysctl.conf\n\nsysctl -p\n\n\n######################install_sub2sing-box#################################################################\n\nif pgrep -x \"sub2sing-box\" > /dev/null; then\n    echo \"kill sub2sing-box...\"\n    pkill -x \"sub2sing-box\"\nfi\nif [ -f \"/usr/bin/sub2sing-box\" ]; then\n    echo \"delete sub2sing-box...\"\n    rm -f /usr/bin/sub2sing-box\nfi\nwget -P /root/ https://github.com/legiz-ru/sub2sing-box/releases/download/v0.0.9/sub2sing-box_0.0.9_linux_amd64.tar.gz\ntar -xvzf /root/sub2sing-box_0.0.9_linux_amd64.tar.gz -C /root/ --strip-components=1 sub2sing-box_0.0.9_linux_amd64/sub2sing-box\nmv /root/sub2sing-box /usr/bin/\nchmod +x /usr/bin/sub2sing-box\nrm /root/sub2sing-box_0.0.9_linux_amd64.tar.gz\nsu -c \"/usr/bin/sub2sing-box server --bind 127.0.0.1 --port 8080 >/dev/null 2>&1 &\"\n\n######################install_fake_site#################################################################\n\nFAKE_SITE_TMP=$(mktemp -d)\nif wget -qO \"$FAKE_SITE_TMP/repo.tar.gz\" \"https://github.com/mozaroc/3x-ui-pro/archive/refs/heads/main.tar.gz\" \\\n	&& tar -xzf \"$FAKE_SITE_TMP/repo.tar.gz\" -C \"$FAKE_SITE_TMP\" --strip-components=3 \"3x-ui-pro-main/assets/fake-sites\"; then\n	FAKE_SITES=(\"$FAKE_SITE_TMP\"/site-*/)\n	FAKE_SITE=\"${FAKE_SITES[$((RANDOM % ${#FAKE_SITES[@]}))]}\"\n	msg_inf \"Random fake site template: $(basename \"$FAKE_SITE\")\"\n	mkdir -p /var/www/html\n	rm -rf /var/www/html/*\n	cp -a \"$FAKE_SITE\". /var/www/html/\n	msg_ok \"Fake site installed successfully!\"\nelse\n	msg_err \"Failed to download fake site templates!\"\nfi\nrm -rf \"$FAKE_SITE_TMP\"\n\n######################install_web_sub_page##############################################################\n\nURL_SUB_PAGE=( \"https://github.com/legiz-ru/x-ui-pro/raw/master/sub-3x-ui.html\"\n		\"https://github.com/legiz-ru/x-ui-pro/raw/master/sub-3x-ui-classical.html\"\n	)\nURL_CLASH_SUB=( \"https://github.com/legiz-ru/x-ui-pro/raw/master/clash/clash.yaml\"\n		\"https://github.com/legiz-ru/x-ui-pro/raw/master/clash/clash_skrepysh.yaml\"\n		\"https://github.com/legiz-ru/x-ui-pro/raw/master/clash/clash_fullproxy_without_ru.yaml\"\n  		\"https://github.com/legiz-ru/x-ui-pro/raw/master/clash/clash_refilter_ech.yaml\"\n	)\nDEST_DIR_SUB_PAGE=\"/var/www/subpage\"\nDEST_FILE_SUB_PAGE=\"$DEST_DIR_SUB_PAGE/index.html\"\nDEST_FILE_CLASH_SUB=\"$DEST_DIR_SUB_PAGE/clash.yaml\"\n\nsudo mkdir -p \"$DEST_DIR_SUB_PAGE\"\n\nsudo curl -L \"${URL_CLASH_SUB[$CLASH]}\" -o \"$DEST_FILE_CLASH_SUB\"\nsudo curl -L \"${URL_SUB_PAGE[$CUSTOMWEBSUB]}\" -o \"$DEST_FILE_SUB_PAGE\"\n\nsed -i \"s/\\${DOMAIN}/$domain/g\" \"$DEST_FILE_SUB_PAGE\"\nsed -i \"s/\\${DOMAIN}/$domain/g\" \"$DEST_FILE_CLASH_SUB\"\nsed -i \"s#\\${SUB_JSON_PATH}#$json_path#g\" \"$DEST_FILE_SUB_PAGE\"\nsed -i \"s#\\${SUB_PATH}#$sub_path#g\" \"$DEST_FILE_SUB_PAGE\"\nsed -i \"s#\\${SUB_PATH}#$sub_path#g\" \"$DEST_FILE_CLASH_SUB\"\nsed -i \"s|sub.legiz.ru|$domain/$sub2singbox_path|g\" \"$DEST_FILE_SUB_PAGE\"\n\n######################cronjob for ssl/reload service/cloudflareips######################################\ncrontab -l | grep -v \"certbot\\|x-ui\\|cloudflareips\" | crontab -\n(crontab -l 2>/dev/null; echo '@reboot /usr/bin/sub2sing-box server --bind 127.0.0.1 --port 8080 > /dev/null 2>&1') | crontab -\n(crontab -l 2>/dev/null; echo '@daily x-ui restart > /dev/null 2>&1 && nginx -s reload;') | crontab -\n(crontab -l 2>/dev/null; echo '@monthly certbot renew --nginx --non-interactive --post-hook \"nginx -s reload\" > /dev/null 2>&1;') | crontab -\n##################################ufw###################################################################\nufw disable\nufw allow 22/tcp\nufw allow 80/tcp\nufw allow 443/tcp\nufw --force enable  \n##################################Show Details##########################################################\n\nif systemctl is-active --quiet x-ui; then clear\n\tprintf '0\\n' | x-ui | grep --color=never -i ':'\n\tmsg_inf \"- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -\"\n\tnginx -T | grep -i 'ssl_certificate\\|ssl_certificate_key'\n\tmsg_inf \"- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -\"\n\tcertbot certificates | grep -i 'Path:\\|Domains:\\|Expiry Date:'\n\n msg_inf \"- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -\"\n\tmsg_inf \"X-UI Secure Panel: https://${domain}/${panel_path}/\\n\"\n \techo -e \"Username:  ${config_username} \\n\" \n\techo -e \"Password:  ${config_password} \\n\" \n\tmsg_inf \"- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -\"\n    msg_inf \"Web Sub Page your first client: https://${domain}/${web_path}?name=first\\n\"\n    msg_inf \"Your local sub2sing-box instance: https://${domain}/$sub2singbox_path/\\n\"\n  msg_inf \"- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -\"\n\tmsg_inf \"Please Save this Screen!!\"\t\nelse\n\tnginx -t && printf '0\\n' | x-ui | grep --color=never -i ':'\n\tmsg_err \"sqlite and x-ui to be checked, try on a new clean linux! \"\nfi\n