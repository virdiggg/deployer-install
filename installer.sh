#!/bin/bash

set -e # Berhenti jika ada error

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Mendeteksi Sistem Operasi...${NC}"

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo -e "${RED}Tidak bisa mendeteksi OS.${NC}"
    exit 1
fi

echo -e "${GREEN}OS terdeteksi: $OS${NC}"

echo -e "${BLUE}Menginstall Dependensi Dasar...${NC}"

case $OS in
    ubuntu|debian)
        sudo apt-get update
        sudo apt-get install -y git unzip curl build-essential ca-certificates gnupg
        ;;

    centos|rhel|rocky|almalinux)
        sudo dnf install -y git unzip curl gcc gcc-c++ make ca-certificates gnupg2
        ;;

    fedora)
        sudo dnf install -y git unzip curl gcc gcc-c++ make ca-certificates gnupg2
        ;;

    arch)
        sudo pacman -Sy --noconfirm git unzip curl base-devel ca-certificates gnupg
        ;;

    *)
        echo -e "${RED}OS tidak didukung oleh script ini.${NC}"
        exit 1
        ;;
esac

# ===============================
# INSTALL DOCKER
# ===============================
echo -e "${BLUE}Mengecek Docker...${NC}"

if command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker sudah terpasang.${NC}"
else
    echo -e "${GREEN}Docker belum ditemukan. Memulai instalasi...${NC}"

    case $OS in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y docker.io
            sudo systemctl enable docker
            sudo systemctl start docker
            ;;

        centos|rhel|rocky|almalinux|fedora)
            sudo dnf install -y docker
            sudo systemctl enable docker
            sudo systemctl start docker
            ;;

        arch)
            sudo pacman -Sy --noconfirm docker
            sudo systemctl enable docker
            sudo systemctl start docker
            ;;

        *)
            echo -e "${RED}Instalasi Docker belum didukung untuk OS ini.${NC}"
            exit 1
            ;;
    esac

    # Tambahkan user ke group docker
    sudo usermod -aG docker $USER
    echo -e "${YELLOW}Silakan logout & login kembali agar group docker aktif.${NC}"
fi

# ===============================
# INSTALL BUN
# ===============================
echo -e "${BLUE}Mengecek Bun Runtime...${NC}"

if command -v bun &> /dev/null; then
    echo -e "${YELLOW}Bun sudah terpasang. Melakukan upgrade...${NC}"
    bun upgrade
else
    echo -e "${GREEN}Bun belum ditemukan. Memulai instalasi baru...${NC}"
    curl -fsSL https://bun.sh/install | bash

    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"

    if ! grep -q "BUN_INSTALL" "$HOME/.bashrc"; then
        echo 'export BUN_INSTALL="$HOME/.bun"' >> "$HOME/.bashrc"
        echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> "$HOME/.bashrc"
    fi
fi

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# ===============================
# INSTALL POSTGRESQL
# ===============================
echo -e "${BLUE}Mengecek PostgreSQL...${NC}"

if command -v psql &> /dev/null; then
    echo -e "${YELLOW}PostgreSQL sudah terpasang.${NC}"
else
    echo -e "${GREEN}PostgreSQL belum ditemukan. Memulai instalasi...${NC}"

    case $OS in
        ubuntu|debian)
            sudo apt-get install -y postgresql postgresql-contrib
            sudo systemctl enable postgresql
            sudo systemctl start postgresql
            ;;

        centos|rhel|rocky|almalinux|fedora)
            sudo dnf install -y postgresql-server postgresql-contrib
            sudo postgresql-setup --initdb || true
            sudo systemctl enable postgresql
            sudo systemctl start postgresql
            ;;

        arch)
            sudo pacman -Sy --noconfirm postgresql
            sudo -u postgres initdb -D /var/lib/postgres/data || true
            sudo systemctl enable postgresql
            sudo systemctl start postgresql
            ;;

        *)
            echo -e "${RED}Instalasi PostgreSQL belum didukung untuk OS ini.${NC}"
            exit 1
            ;;
    esac
fi


# ===============================
# INSTALL GO
# ===============================
echo -e "${BLUE}Mengecek Go...${NC}"

if command -v go &> /dev/null; then
    echo -e "${YELLOW}Go sudah terpasang.${NC}"
else
    echo -e "${GREEN}Go belum ditemukan. Memulai instalasi...${NC}"

    case $OS in
        ubuntu|debian)
            sudo apt-get install -y golang
            ;;

        centos|rhel|rocky|almalinux|fedora)
            sudo dnf install -y golang
            ;;

        arch)
            sudo pacman -Sy --noconfirm go
            ;;

        *)
            echo -e "${RED}Instalasi Go belum didukung untuk OS ini.${NC}"
            exit 1
            ;;
    esac
fi


# ===============================
# INSTALL PGROLL
# ===============================
echo -e "${BLUE}Mengecek pgroll...${NC}"

if command -v pgroll &> /dev/null; then
    echo -e "${YELLOW}pgroll sudah terpasang.${NC}"
else
    echo -e "${GREEN}pgroll belum ditemukan. Menginstall via go install...${NC}"

    # Pastikan GOPATH/bin ada di PATH
    export PATH=$PATH:$(go env GOPATH)/bin

    go install github.com/xataio/pgroll@latest

    echo -e "${GREEN}pgroll berhasil diinstall.${NC}"
fi

# ===============================
# DOWNLOAD REPO
# ===============================

echo -e "${BLUE}Menyiapkan Repository Deployer (Download ZIP)...${NC}"
TARGET_DIR="$HOME/deployer"
REPO_URL="https://github.com/virdiggg/deployer"
BRANCH="master"
ZIP_FILE="/tmp/deployer_temp.zip"

echo -e "${BLUE}Menyiapkan direktori target: $TARGET_DIR${NC}"

if [ -d "$TARGET_DIR" ]; then
    echo -e "${YELLOW}Folder lama ditemukan di $TARGET_DIR. Menghapus...${NC}"
    rm -rf "$TARGET_DIR"
fi

echo -e "${BLUE}Mengunduh repository dari $BRANCH...${NC}"
curl -L "$REPO_URL/archive/refs/heads/$BRANCH.zip" -o "$ZIP_FILE"

echo -e "${BLUE}Mengekstrak ke folder sementara...${NC}"
TEMP_EXTRACT_DIR="/tmp/deployer_extract_$(date +%s)"
mkdir -p "$TEMP_EXTRACT_DIR"
unzip -q "$ZIP_FILE" -d "$TEMP_EXTRACT_DIR"

EXTRACTED_FOLDER=$(ls "$TEMP_EXTRACT_DIR")

mv "$TEMP_EXTRACT_DIR/$EXTRACTED_FOLDER" "$TARGET_DIR"

rm -f "$ZIP_FILE"
rm -rf "$TEMP_EXTRACT_DIR"

echo -e "${BLUE}Berhasil! Repository siap di: $TARGET_DIR${NC}"
cd "$TARGET_DIR"

# ===============================
# INSTALL DEPENDENCIES
# ===============================
echo -e "${BLUE}Menginstall Dependencies Project via Bun...${NC}"
bun install

echo -e "${GREEN}Setup Selesai!${NC}"
echo -e "Silakan jalankan server dengan perintah:"
echo -e "${YELLOW}cd deployer && bun run src/index.ts${NC}"