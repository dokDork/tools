#!/bin/bash

# ==========================================
# GESTIONE CONFIGURAZIONI ICONE DESKTOP KALI
# ==========================================

CONFIG="$HOME/.config/xfce4/desktop/icons.screen0.yaml"
BACKUP_DIR="$HOME/config/desktop"
SAFETY="$BACKUP_DIR/backup-prima-del-ripristino.yaml"

mkdir -p "$BACKUP_DIR"

echo
echo "======================================"
echo "       GESTIONE DESKTOP KALI"
echo "======================================"
echo
echo "1 - Salva una nuova configurazione"
echo "2 - Ripristina una configurazione"
echo "3 - Esci"
echo

read -rp "Seleziona un'opzione: " SCELTA

case "$SCELTA" in

    1)
        echo
        read -rp "Nome della configurazione: " NOME

        # Controllo nome
        if [[ -z "$NOME" || ! "$NOME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            echo "Nome non valido. Usa lettere, numeri, - oppure _."
            exit 1
        fi

        DEST="$BACKUP_DIR/desktop-$NOME.yaml"

        if [ -f "$DEST" ]; then
            echo "Esiste già una configurazione con questo nome."
            read -rp "Vuoi sovrascriverla? [S/N]: " CONFERMA

            if [[ ! "$CONFERMA" =~ ^[Ss]$ ]]; then
                echo "Salvataggio annullato."
                exit 0
            fi
        fi

        if [ ! -f "$CONFIG" ]; then
            echo "ERRORE: configurazione desktop non trovata."
            exit 1
        fi

        cp "$CONFIG" "$DEST"

        echo
        echo "Configurazione salvata correttamente!"
        echo "Nome: $NOME"
        echo "File: $DEST"
        ;;

    2)
        echo
        echo "CONFIGURAZIONI DISPONIBILI"
        echo "--------------------------------------"

        mapfile -t CONFIGURAZIONI < <(
            find "$BACKUP_DIR" -maxdepth 1 -type f \
                -name 'desktop-*.yaml' | sort
        )

        if [ ${#CONFIGURAZIONI[@]} -eq 0 ]; then
            echo "Nessuna configurazione salvata."
            exit 0
        fi

        for i in "${!CONFIGURAZIONI[@]}"; do
            NOME=$(basename "${CONFIGURAZIONI[$i]}" .yaml)
            NOME=${NOME#desktop-}
            printf "%2d - %s\n" "$((i+1))" "$NOME"
        done

        echo
        read -rp "Indica il numero della configurazione: " NUMERO

        if [[ ! "$NUMERO" =~ ^[0-9]+$ ]] ||
           (( NUMERO < 1 || NUMERO > ${#CONFIGURAZIONI[@]} )); then
            echo "Numero non valido."
            exit 1
        fi

        SELEZIONATA="${CONFIGURAZIONI[$((NUMERO-1))]}"

        echo
        echo "Configurazione selezionata:"
        echo "$(basename "$SELEZIONATA")"

        read -rp "Confermi il ripristino? [S/N]: " CONFERMA

        if [[ ! "$CONFERMA" =~ ^[Ss]$ ]]; then
            echo "Ripristino annullato."
            exit 0
        fi

        if [ ! -f "$CONFIG" ]; then
            echo "ERRORE: file di configurazione corrente non trovato."
            exit 1
        fi

        # Salva lo stato corrente prima del ripristino
        cp "$CONFIG" "$SAFETY"

        # Chiude XFCE Desktop
        xfdesktop --quit
        sleep 2

        # Ripristina la configurazione scelta
        cp "$SELEZIONATA" "$CONFIG"

        # Riavvia XFCE Desktop
        xfdesktop &

        echo
        echo "Configurazione ripristinata correttamente!"
        echo "Configurazione: $(basename "$SELEZIONATA")"
        echo "Backup precedente: $SAFETY"
        ;;

    3)
        echo "Uscita."
        exit 0
        ;;

    *)
        echo "Opzione non valida."
        exit 1
        ;;

esac
