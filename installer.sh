#!/bin/bash

set -e # Berhenti jika ada error

# Warna untuk output agar lebih cantik
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🔍 Mendeteksi Sistem Operasi...${NC}"

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo -e "${RED}Tidak bisa mendeteksi OS.${NC}"
    exit 1
fi

echo -e "${GREEN}OS terdeteksi: $OS${NC}"

echo -e "${BLUE}📦 Menginstall Dependensi Dasar...${NC}"

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
echo -e "${BLUE}🐳 Mengecek Docker...${NC}"

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
echo -e "${BLUE}⚡ Mengecek Bun Runtime...${NC}"

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
# DOWNLOAD REPO
# ===============================
echo -e "${BLUE}📂 Menyiapkan Repository Deployer (Download ZIP)...${NC}"

REPO_URL="https://github.com/USER/REPO-DEPLOYER"
BRANCH="main"
FOLDER_NAME="deployer"
ZIP_FILE="deployer.zip"

# Hapus folder lama jika ada
if [ -d "$FOLDER_NAME" ]; then
    echo -e "${YELLOW}Folder lama ditemukan. Menghapus...${NC}"
    rm -rf "$FOLDER_NAME"
fi

# Hapus zip lama jika ada
if [ -f "$ZIP_FILE" ]; then
    rm -f "$ZIP_FILE"
fi

echo -e "${BLUE}⬇️  Mengunduh repository sebagai ZIP...${NC}"
curl -L "$REPO_URL/archive/refs/heads/$BRANCH.zip" -o "$ZIP_FILE"

echo -e "${BLUE}📦 Mengekstrak file...${NC}"
unzip -q "$ZIP_FILE"

# Rename folder hasil extract (biasanya REPO-DEPLOYER-main)
EXTRACTED_FOLDER=$(unzip -Z -1 "$ZIP_FILE" | head -1 | cut -f1 -d"/")

mv "$EXTRACTED_FOLDER" "$FOLDER_NAME"

# Hapus zip setelah extract
rm -f "$ZIP_FILE"

cd "$FOLDER_NAME"

# ===============================
# INSTALL DEPENDENCIES
# ===============================
echo -e "${BLUE}🛠  Menginstall Dependencies Project via Bun...${NC}"
bun install

echo -e "${GREEN}✅ Setup Selesai!${NC}"
echo -e "Silakan jalankan server dengan perintah:"
echo -e "${YELLOW}cd elysia-deployer && bun run src/index.ts${NC}"