#!/bin/bash

# To Stop FTP service
# sudo systemctl stop vsftpd

#!/bin/bash
# ==============================================================
# setup_ftp.sh - Attiva il servizio vsftpd su Kali Linux
# Uso: sudo ./setup_ftp.sh <username> <password>
# ==============================================================

set -e

# ---------- Colori per output ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log()    { echo -e "${GREEN}[+]${NC} $1"; }
warn()   { echo -e "${YELLOW}[!]${NC} $1"; }
error()  { echo -e "${RED}[-]${NC} $1"; exit 1; }

# ---------- Controllo root ----------
[[ $EUID -ne 0 ]] && error "Esegui lo script come root: sudo $0 <username> <password>"

# ---------- Controllo parametri con spiegazione dettagliata ----------
if [[ $# -eq 0 ]]; then
    echo -e "${RED}============================================${NC}"
    echo -e "${RED}  ERRORE: Nessun parametro fornito!${NC}"
    echo -e "${RED}============================================${NC}"
    echo ""
    echo -e "  Questo script richiede ${YELLOW}due parametri obbligatori${NC}:"
    echo ""
    echo -e "  ${YELLOW}1. <username>${NC}"
    echo -e "     Il nome utente che verrà creato (o aggiornato)"
    echo -e "     sul sistema per accedere al server FTP."
    echo -e "     Esempio: ${GREEN}ftpuser${NC}"
    echo ""
    echo -e "  ${YELLOW}2. <password>${NC}"
    echo -e "     La password associata all'utente FTP."
    echo -e "     Usare una password robusta (min. 8 caratteri)."
    echo -e "     Esempio: ${GREEN}MyS3cur3Pass!${NC}"
    echo ""
    echo -e "  ${YELLOW}Uso corretto:${NC}"
    echo -e "     sudo $0 <username> <password>"
    echo -e "     sudo $0 ftpuser MyS3cur3Pass!"
    echo ""
    exit 1

elif [[ $# -eq 1 ]]; then
    echo -e "${RED}============================================${NC}"
    echo -e "${RED}  ERRORE: Parametro mancante!${NC}"
    echo -e "${RED}============================================${NC}"
    echo ""
    echo -e "  Hai fornito solo ${YELLOW}1 parametro su 2${NC} richiesti."
    echo ""
    echo -e "  ${GREEN}Username ricevuto :${NC} '$1'"
    echo -e "  ${RED}Password         :${NC} ✘ non fornita"
    echo ""
    echo -e "  ${YELLOW}Fornisci anche la password:${NC}"
    echo -e "     sudo $0 $1 <password>"
    echo ""
    exit 1

elif [[ $# -gt 2 ]]; then
    echo -e "${RED}============================================${NC}"
    echo -e "${RED}  ERRORE: Troppi parametri!${NC}"
    echo -e "${RED}============================================${NC}"
    echo ""
    echo -e "  Hai fornito ${YELLOW}$# parametri${NC}, ma ne sono accettati solo ${YELLOW}2${NC}."
    echo -e "  Attenzione: se la password contiene spazi, racchiudila tra virgolette."
    echo ""
    echo -e "  ${YELLOW}Uso corretto:${NC}"
    echo -e "     sudo $0 <username> <password>"
    echo -e "     sudo $0 ftpuser \"La Mia Password!\""
    echo ""
    exit 1
fi

FTP_USER="$1"
FTP_PASS="$2"

# ---------- Validazione username ----------
if [[ ! "$FTP_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
    echo -e "${RED}============================================${NC}"
    echo -e "${RED}  ERRORE: Username non valido!${NC}"
    echo -e "${RED}============================================${NC}"
    echo ""
    echo -e "  L'username ${YELLOW}'$FTP_USER'${NC} non è valido."
    echo -e "  Regole per un username corretto:"
    echo -e "    - Inizia con una lettera minuscola o underscore ( _ )"
    echo -e "    - Contiene solo lettere minuscole, numeri, - oppure _"
    echo -e "    - Lunghezza massima: 32 caratteri"
    echo ""
    exit 1
fi

# ---------- Validazione password (lunghezza minima) ----------
if [[ ${#FTP_PASS} -lt 8 ]]; then
    echo -e "${RED}============================================${NC}"
    echo -e "${RED}  ERRORE: Password troppo corta!${NC}"
    echo -e "${RED}============================================${NC}"
    echo ""
    echo -e "  La password deve contenere almeno ${YELLOW}8 caratteri${NC}."
    echo -e "  Caratteri forniti: ${YELLOW}${#FTP_PASS}${NC}"
    echo ""
    exit 1
fi

CHROOT_LIST="/etc/vsftpd.chroot_list"
VSFTPD_CONF="/etc/vsftpd.conf"
VSFTPD_CONF_BAK="/etc/vsftpd.conf.bak.$(date +%s)"
PASV_MIN=10090
PASV_MAX=10100

# ---------- Stop servizio esistente ----------
if systemctl is-active --quiet vsftpd; then
    warn "Servizio vsftpd già attivo. Lo fermo prima di riconfigurare..."
    systemctl stop vsftpd
    log "vsftpd fermato."
else
    log "Nessun servizio vsftpd attivo, procedo con l'installazione."
fi

# ---------- Installazione vsftpd ----------
log "Installazione vsftpd..."
apt-get install -y vsftpd > /dev/null 2>&1
log "vsftpd installato."

# ---------- Backup configurazione ----------
[[ -f "$VSFTPD_CONF" ]] && cp "$VSFTPD_CONF" "$VSFTPD_CONF_BAK" && warn "Backup config: $VSFTPD_CONF_BAK"

# ---------- Scrittura /etc/vsftpd.conf ----------
log "Scrittura configurazione vsftpd..."
cat > "$VSFTPD_CONF" <<EOF
# vsftpd.conf - generato da setup_ftp.sh

# --- Utenti locali ---
local_enable=YES
write_enable=YES
local_umask=022

# --- Chroot ---
chroot_local_user=YES
chroot_list_enable=YES
chroot_list_file=$CHROOT_LIST
allow_writeable_chroot=YES

# --- Modalità standalone (IPv4) ---
listen=YES
listen_ipv6=NO

# --- Passive mode (tutte le interfacce) ---
pasv_enable=YES
pasv_min_port=$PASV_MIN
pasv_max_port=$PASV_MAX
# pasv_address non impostato: vsftpd ascolta su tutte le interfacce

# --- Sicurezza e log ---
anonymous_enable=NO
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
EOF
log "Configurazione scritta in $VSFTPD_CONF"

# ---------- Creazione utente FTP ----------
if id "$FTP_USER" &>/dev/null; then
    warn "L'utente '$FTP_USER' esiste già. Aggiorno solo la password."
else
    log "Creazione utente '$FTP_USER'..."
    useradd -m -s /bin/bash "$FTP_USER"
fi

echo "$FTP_USER:$FTP_PASS" | chpasswd
log "Password impostata per '$FTP_USER'."

# ---------- Chroot list ----------
log "Aggiornamento $CHROOT_LIST..."
touch "$CHROOT_LIST"
grep -qxF "$FTP_USER" "$CHROOT_LIST" || echo "$FTP_USER" >> "$CHROOT_LIST"
log "Utente '$FTP_USER' aggiunto a $CHROOT_LIST."

# ---------- Home directory: permessi corretti per chroot ----------
chmod 755 "/home/$FTP_USER"

FTP_UPLOAD_DIR="/home/$FTP_USER/upload"
mkdir -p "$FTP_UPLOAD_DIR"
chown "$FTP_USER":"$FTP_USER" "$FTP_UPLOAD_DIR"
chmod 755 "$FTP_UPLOAD_DIR"
log "Directory upload: $FTP_UPLOAD_DIR"

# ---------- Avvio servizio ----------
log "Avvio vsftpd..."
systemctl enable vsftpd > /dev/null 2>&1
systemctl restart vsftpd
log "vsftpd avviato e abilitato al boot."

# ---------- Regole iptables per passive mode ----------
log "Apertura porte iptables (21 + PASV $PASV_MIN:$PASV_MAX)..."
iptables -I INPUT -p tcp --dport 21 -j ACCEPT
iptables -I INPUT -p tcp --dport "${PASV_MIN}:${PASV_MAX}" -j ACCEPT
log "Regole iptables aggiunte."

# ---------- Verifica ----------
log "Verifica porta 21..."
if ss -antlp | grep -q ':21'; then
    log "Porta 21 in ascolto. ✔"
else
    error "La porta 21 non risulta in ascolto. Controlla il log: journalctl -u vsftpd"
fi

# ---------- Riepilogo ----------
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  FTP Server pronto!${NC}"
echo -e "${GREEN}============================================${NC}"
echo -e "  Interfacce       : ${YELLOW}tutte (0.0.0.0)${NC}"
echo -e "  Porta FTP        : ${YELLOW}21${NC}"
echo -e "  Porte PASV       : ${YELLOW}${PASV_MIN}-${PASV_MAX}${NC}"
echo -e "  Utente           : ${YELLOW}${FTP_USER}${NC}"
echo -e "  Directory upload : ${YELLOW}${FTP_UPLOAD_DIR}${NC}"
echo -e "  Connetti con     : ${YELLOW}ftp <IP_KALI>${NC}"
echo -e "${GREEN}============================================${NC}"
