#!/usr/bin/env bash
#set -x
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 
    exit 1
fi
add_script() {
cat <<EOF > $ALERTSCRIPT_PATH
#!/usr/bin/env bash
# Import credentials form config file
. /opt/ssh-login-alert/credentials.config
for i in "\${USERID[@]}"
	do
	URL="https://api.telegram.org/bot\${KEY}/sendMessage"
	DATE="\$(date "+%d %b %Y %H:%M")"

	if [ -n "\$SSH_CLIENT" ]; then
		CLIENT_IP=\$(echo \$SSH_CLIENT | awk '{print \$1}')

		SRV_HOSTNAME=\$(hostname -f)
		SRV_IP=\$(hostname -I | awk '{print \$1}')

		TEXT="Connection from *\${CLIENT_IP}* as *\${USER}* on *\${SRV_HOSTNAME}* (*\${SRV_IP}*) at *\${DATE}*"

		curl -s -d "chat_id=\$i&text=\${TEXT}&disable_web_page_preview=true&parse_mode=markdown" \$URL > /dev/null
		$SSH_DB_LOGGER
	fi &
done
EOF
}

add_profiled() {
cat <<EOF > /etc/profile.d/telegram-alert.sh
#!/usr/bin/env bash
# Log connections
bash $ALERTSCRIPT_PATH
EOF
}

add_zsh () {
cat <<EOF >> /etc/zsh/zshrc

# Log connections
bash $ALERTSCRIPT_PATH
EOF
}

logging() {
    read -p "[?] Would you log ssh to database ? (y/n) "  sshdb
    if [[ $sshdb == "y" || $sshdb == "Y" ]]; then
        read -p "[?] Insert your server IP (e.g 172.18.1.137) " sshdbserv
	SSH_DB_LOGGER="curl -s http://$sshdbserv/api.php -X POST -d \"client_ip=\${CLIENT_IP}&user=\${USER}&hostname=\${SRV_HOSTNAME}&server_ip=\${SRV_IP}\" "	
    fi
    echo "[i] Thanks"
}
copy_config() {
    echo "[i] Copy config into /opt/ssh-login-alert"
    add_script
    cp credentials.config /opt/ssh-login-alert/
    echo "[!] Done!"
}

ALERTSCRIPT_PATH="/opt/ssh-login-alert/alert.sh"


echo "[+] Deploying alerts..."
logging
add_profiled

echo "[i] Check if ZSH is installed.."

HAS_ZSH=$(grep -o -m 1 "zsh" /etc/shells)
if [ ! -z $HAS_ZSH ]; then
    echo "[+] ZSH is installed, deploy alerts to zshrc"
    add_zsh
else
    echo "[i] No zsh detected"
fi

echo "[i] Check if directory is exist"
if [ ! -d /opt/ssh-login-alert ]; then
	echo "[i] Creating Directory"
	mkdir /opt/ssh-login-alert/
else
	echo "[i] Directory exist"
	read -p "[?] Would you overwrite existing configuration ? (y/n) " ovwrt
	if [[ $ovwrt == "y" || $ovwrt == "Y" ]]; then
		copy_config	
		exit
	else
		echo "[!] exit nothing changes"
		exit
	fi
fi
copy_config	
