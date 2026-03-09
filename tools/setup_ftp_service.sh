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

# ---------- Parametri ----------
if [[ $# -ne 2 ]]; then
    echo "Uso: sudo $0 <username> <password>"
    exit 1
fi

FTP_USER="$1"
FTP_PASS="$2"
CHROOT_LIST="/etc/vsftpd.chroot_list"
VSFTPD_CONF="/etc/vsftpd.conf"
VSFTPD_CONF_BAK="/etc/vsftpd.conf.bak.$(date +%s)"
PASV_MIN=10090
PASV_MAX=10100

# ---------- Rileva IP pubblico/locale ----------
# Prova prima l'IP pubblico, poi fallback su IP locale
log "Rilevamento indirizzo IP..."
PUBLIC_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || true)
if [[ -z "$PUBLIC_IP" ]]; then
    warn "Impossibile ottenere IP pubblico, uso IP locale"
    PUBLIC_IP=$(hostname -I | awk '{print $1}')
fi
log "IP usato per PASV: ${PUBLIC_IP}"

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

# --- Passive mode ---
pasv_enable=YES
pasv_min_port=$PASV_MIN
pasv_max_port=$PASV_MAX
pasv_address=$PUBLIC_IP

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
# Aggiungi l'utente solo se non già presente
grep -qxF "$FTP_USER" "$CHROOT_LIST" || echo "$FTP_USER" >> "$CHROOT_LIST"
log "Utente '$FTP_USER' aggiunto a $CHROOT_LIST."

# ---------- Home directory: permessi corretti per chroot ----------
# vsftpd richiede che la home dell'utente NON sia scrivibile da altri
chmod 755 "/home/$FTP_USER"

# Crea una sottodirectory scrivibile dall'utente per gli upload
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
echo -e "  Host (PASV addr) : ${YELLOW}${PUBLIC_IP}${NC}"
echo -e "  Porta FTP        : ${YELLOW}21${NC}"
echo -e "  Porte PASV       : ${YELLOW}${PASV_MIN}-${PASV_MAX}${NC}"
echo -e "  Utente           : ${YELLOW}${FTP_USER}${NC}"
echo -e "  Directory upload : ${YELLOW}${FTP_UPLOAD_DIR}${NC}"
echo -e "  Connetti con     : ${YELLOW}ftp ${PUBLIC_IP}${NC}"
echo -e "${GREEN}============================================${NC}"
