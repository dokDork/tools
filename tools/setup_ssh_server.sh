# To Stop SSH service
# sudo systemctl stop ssh

#!/bin/bash

# Verifica esecuzione come root
if [ "$EUID" -ne 0 ]; then
    echo "Esegui lo script come root."
    exit 1
fi

# Controllo parametri
if [ $# -ne 2 ]; then
    echo "Uso: $0 <username> <password>"
    exit 1
fi

USERNAME=$1
PASSWORD=$2
HOME_DIR="/home/$USERNAME"

echo "[+] Creazione utente $USERNAME..."

# Crea home directory
mkdir -p $HOME_DIR

# Crea utente
useradd -d $HOME_DIR -s /bin/bash $USERNAME

# Imposta password
echo "$USERNAME:$PASSWORD" | chpasswd

# Permessi home
chown -R $USERNAME:$USERNAME $HOME_DIR
chmod 700 $HOME_DIR

echo "[+] Configurazione directory .ssh..."

# Crea directory .ssh
mkdir -p $HOME_DIR/.ssh
chmod 700 $HOME_DIR/.ssh
chown $USERNAME:$USERNAME $HOME_DIR/.ssh

# Inserimento chiave pubblica (se presente nella directory corrente)
if [ -f id_rsa.pub ]; then
    cat id_rsa.pub >> $HOME_DIR/.ssh/authorized_keys
    chmod 600 $HOME_DIR/.ssh/authorized_keys
    chown $USERNAME:$USERNAME $HOME_DIR/.ssh/authorized_keys
    echo "[+] Chiave pubblica aggiunta."
else
    echo "[!] File id_rsa.pub non trovato. Salto inserimento chiave."
fi

echo "[+] Backup configurazione SSH..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

echo "[+] Configurazione sshd_config..."

# Impostazioni sicurezza
sed -i 's/^#*Protocol.*/Protocol 2/' /etc/ssh/sshd_config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Banner (se esiste)
if [ -f /dir/banner.txt ]; then
    echo "Banner /dir/banner.txt" >> /etc/ssh/sshd_config
fi

# Restrizione utenti (modifica qui se necessario)
echo "AllowUsers $USERNAME" >> /etc/ssh/sshd_config

echo "[+] Riavvio servizio SSH..."
systemctl restart ssh 2>/dev/null || service ssh restart

echo "[✔] Server SSH configurato correttamente."
