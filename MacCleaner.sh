#!/usr/bin/env bash
# ============================================================
# MacCleaner v1.0 - macOS 安全清理工具 / macOS Safe Cleaner
# 支援 macOS 10.12+，以使用者身份執行，無需管理員密碼
# Supports macOS 10.12+, runs as current user, no sudo needed
# ============================================================

# ============================================================
# SECTION 1: COLORS & SETUP / 顏色設定
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
DYELLOW='\033[0;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
DGREEN='\033[0;32m'
NC='\033[0m'

# ============================================================
# SECTION 2: GLOBAL STATE / 全域變數
# ============================================================
TOTAL_FREED=0
RESULT_NAMES=()
RESULT_FREED=()

# ============================================================
# SECTION 3: UTILITY FUNCTIONS / 工具函式
# ============================================================

format_bytes() {
    local bytes=$1
    awk -v b="$bytes" 'BEGIN {
        if      (b >= 1073741824) printf "%.2f GB", b/1073741824
        else if (b >= 1048576)   printf "%.1f MB", b/1048576
        else if (b >= 1024)      printf "%d KB",   b/1024
        else                     printf "%d B",     b
    }'
}

get_dir_size_bytes() {
    local path="$1"
    [ ! -e "$path" ] && { echo 0; return; }
    local kb
    kb=$(du -sk "$path" 2>/dev/null | awk '{print $1}')
    echo $(( ${kb:-0} * 1024 ))
}

remove_dir_contents() {
    # 安全清除資料夾內容，回傳已釋放位元組
    # Safely removes folder contents, returns freed bytes
    local dir="$1"
    [ ! -d "$dir" ] && { echo 0; return; }
    local before_kb after_kb freed
    before_kb=$(du -sk "$dir" 2>/dev/null | awk '{print $1}')
    before_kb=${before_kb:-0}
    find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} \; 2>/dev/null || true
    after_kb=$(du -sk "$dir" 2>/dev/null | awk '{print $1}')
    after_kb=${after_kb:-0}
    freed=$(( (before_kb - after_kb) * 1024 ))
    [ "$freed" -lt 0 ] && freed=0
    echo "$freed"
}

record_result() {
    RESULT_NAMES+=("$1")
    RESULT_FREED+=("$2")
}

print_c() {
    local text="$1" color="${2:-$WHITE}" nonl="${3:-}"
    if [ -n "$nonl" ]; then
        printf "${color}%s${NC}" "$text"
    else
        printf "${color}%s${NC}\n" "$text"
    fi
}

task_start() {
    printf "${GRAY}  [ ] ${CYAN}%s${GRAY} / %s ...${NC}" "$1" "$2"
}

task_done() {
    local freed=$1 label="${2:-}"
    echo ""
    if [ -n "$label" ]; then
        print_c "  [v] $label" "$GREEN"
    elif [ "$freed" -gt 0 ]; then
        printf "${GREEN}  [v] ${WHITE}釋放 ${YELLOW}%s${NC}\n" "$(format_bytes "$freed")"
    else
        print_c "  [v] 已完成 / Done" "$GREEN"
    fi
}

task_skip() {
    echo ""
    print_c "  [-] 略過 / Skipped: $1" "$GRAY"
}

# ============================================================
# SECTION 4: UI / 使用者介面
# ============================================================

show_header() {
    clear
    echo ""
    print_c "  +========================================================+" "$CYAN"
    print_c "  |                                                        |" "$CYAN"
    print_c "  |        macOS 系統安全清理工具  v1.0                   |" "$YELLOW"
    print_c "  |        MacCleaner - macOS Safety Cleaner v1.0         |" "$WHITE"
    print_c "  |                                                        |" "$CYAN"
    print_c "  +========================================================+" "$CYAN"
    echo ""
    local macos_ver
    macos_ver=$(sw_vers -productVersion 2>/dev/null || echo "Unknown")
    print_c "  系統 / OS: macOS $macos_ver  |  使用者 / User: $USER" "$GRAY"
    echo ""
}

show_main_menu() {
    print_c "  +---------------------------------------------+" "$GREEN"
    print_c "  |         請選擇功能 / Choose Function        |" "$GREEN"
    print_c "  +---------------------------------------------+" "$GREEN"
    print_c "  |                                             |" "$GREEN"
    print_c "  |  [1]  一鍵全部清理 Full Clean  (推薦)      |" "$WHITE"
    print_c "  |                                             |" "$GREEN"
    print_c "  |  [2]  自選清理項目 Selective Clean          |" "$WHITE"
    print_c "  |                                             |" "$GREEN"
    print_c "  |  [3]  系統資訊 System Info                  |" "$WHITE"
    print_c "  |                                             |" "$GREEN"
    print_c "  |  [Q]  離開 Exit                             |" "$WHITE"
    print_c "  |                                             |" "$GREEN"
    print_c "  +---------------------------------------------+" "$GREEN"
    echo ""
    printf "${YELLOW}  請輸入選項 / Enter choice [1/2/3/Q]: ${NC}"
}

show_selective_menu() {
    print_c "  +-----------------------------------------------------+" "$CYAN"
    print_c "  |  選擇要清理的項目 / Select items to clean           |" "$CYAN"
    print_c "  +-----------------------------------------------------+" "$CYAN"
    printf "${WHITE}  [ 1]  使用者快取 / User Caches${NC}\n"
    printf "${WHITE}  [ 2]  使用者日誌 / User Logs${NC}\n"
    printf "${WHITE}  [ 3]  資源回收筒 / Trash${NC}\n"
    printf "${WHITE}  [ 4]  瀏覽器快取 / Browser Cache${NC}\n"
    printf "${WHITE}  [ 5]  App 快取 / App Cache (Discord/Slack/Zoom...)${NC}\n"
    printf "${WHITE}  [ 6]  Xcode 快取 / Xcode DerivedData${NC}\n"
    printf "${WHITE}  [ 7]  .DS_Store 隱藏檔 / DS_Store Files${NC}\n"
    printf "${WHITE}  [ 8]  下載暫存檔 / Downloads Temp Files${NC}\n"
    print_c "  +-----------------------------------------------------+" "$CYAN"
    echo ""
    print_c "  輸入編號 (逗號分隔，如: 1,3,5) 或 [A] 全選" "$YELLOW"
    printf "${GRAY}  Enter numbers (e.g. 1,3,5) or [A] for All: ${NC}"
}

show_system_info() {
    show_header
    print_c "  系統資訊 / System Information" "$CYAN"
    print_c "  ─────────────────────────────────────────────────────" "$GRAY"
    echo ""

    local ver name
    ver=$(sw_vers -productVersion 2>/dev/null)
    name=$(sw_vers -productName 2>/dev/null)
    print_c "  作業系統: $name $ver" "$WHITE"

    local total_ram total_gb
    total_ram=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
    total_gb=$(awk -v r="$total_ram" 'BEGIN{printf "%.1f", r/1073741824}')
    local free_pages page_size free_mb
    page_size=$(vm_stat 2>/dev/null | awk '/page size/{print $NF+0}')
    free_pages=$(vm_stat 2>/dev/null | awk '/^Pages free/{print $3+0}')
    page_size=${page_size:-4096}
    free_pages=${free_pages:-0}
    free_mb=$(( free_pages * page_size / 1048576 ))
    print_c "  記憶體: 總計 ${total_gb}GB  (即時可用約 ${free_mb}MB)" "$WHITE"

    echo ""
    print_c "  磁碟空間 / Disk Space:" "$CYAN"
    df -h / 2>/dev/null | awk 'NR==2{printf "    Macintosh HD:  已用 %s / 總計 %s  (剩 %s)\n",$3,$2,$4}'

    echo ""
    local cache_size log_size trash_size
    cache_size=$(get_dir_size_bytes "$HOME/Library/Caches")
    log_size=$(get_dir_size_bytes "$HOME/Library/Logs")
    trash_size=$(get_dir_size_bytes "$HOME/.Trash")
    printf "  快取大小 / Cache size:  ${YELLOW}%s${NC}\n" "$(format_bytes "$cache_size")"
    printf "  日誌大小 / Log size:    ${YELLOW}%s${NC}\n" "$(format_bytes "$log_size")"
    printf "  資源回收筒 / Trash:     ${YELLOW}%s${NC}\n" "$(format_bytes "$trash_size")"

    echo ""
    print_c "  按 Enter 返回 / Press Enter to go back..." "$GRAY"
    read -r
}

# ============================================================
# SECTION 5: CLEANING FUNCTIONS / 清理函式
# ============================================================

clear_user_caches() {
    task_start "使用者快取" "User Caches"
    local freed
    freed=$(remove_dir_contents "$HOME/Library/Caches")
    TOTAL_FREED=$(( TOTAL_FREED + freed ))
    record_result "使用者快取 / User Caches" "$freed"
    task_done "$freed"
}

clear_user_logs() {
    task_start "使用者日誌" "User Logs"
    local freed
    freed=$(remove_dir_contents "$HOME/Library/Logs")
    TOTAL_FREED=$(( TOTAL_FREED + freed ))
    record_result "使用者日誌 / User Logs" "$freed"
    task_done "$freed"
}

empty_trash() {
    task_start "資源回收筒" "Trash"
    local trash="$HOME/.Trash"
    local size
    size=$(get_dir_size_bytes "$trash")

    if [ "$size" -eq 0 ]; then
        task_skip "資源回收筒已是空的 / Already empty"
        record_result "資源回收筒 / Trash" 0
        return
    fi

    echo ""
    printf "${YELLOW}  !! 資源回收筒有 %s，確認清空? [Y/N]: ${NC}" "$(format_bytes "$size")"
    read -r confirm
    case "$confirm" in
        [Yy]|[Yy][Ee][Ss]|是)
            find "$trash" -mindepth 1 -exec rm -rf {} \; 2>/dev/null || true
            local freed=$(( size - $(get_dir_size_bytes "$trash") ))
            [ "$freed" -lt 0 ] && freed=0
            TOTAL_FREED=$(( TOTAL_FREED + freed ))
            record_result "資源回收筒 / Trash" "$freed"
            task_done "$freed"
            ;;
        *)
            task_skip "使用者取消 / Cancelled"
            record_result "資源回收筒 / Trash" 0
            ;;
    esac
}

clear_browser_cache() {
    task_start "瀏覽器快取" "Browser Cache"
    local freed=0

    # ── Chrome ────────────────────────────────────────────────
    local chrome_base="$HOME/Library/Application Support/Google/Chrome"
    if [ -d "$chrome_base" ]; then
        local cf=0
        local cache_dirs="Cache Cache2 Code Cache GPUCache Media Cache ShaderCache"
        for prof in "$chrome_base/Default" "$chrome_base"/Profile\ */; do
            [ -d "$prof" ] || continue
            for cd in Cache "Cache2" "Code Cache" GPUCache "Media Cache" ShaderCache; do
                cf=$(( cf + $(remove_dir_contents "$prof/$cd") ))
            done
        done
        if [ "$cf" -gt 0 ]; then
            echo ""; printf "${DGREEN}    Chrome: %s${NC}\n" "$(format_bytes "$cf")"
        fi
        freed=$(( freed + cf ))
    fi

    # ── Safari ────────────────────────────────────────────────
    local sf=0
    sf=$(( sf + $(remove_dir_contents "$HOME/Library/Caches/com.apple.Safari") ))
    sf=$(( sf + $(remove_dir_contents "$HOME/Library/Safari/LocalStorage") ))
    if [ "$sf" -gt 0 ]; then
        printf "${DGREEN}    Safari: %s${NC}\n" "$(format_bytes "$sf")"
    fi
    freed=$(( freed + sf ))

    # ── Firefox ───────────────────────────────────────────────
    local ff_base="$HOME/Library/Application Support/Firefox/Profiles"
    if [ -d "$ff_base" ]; then
        local ff=0
        for prof in "$ff_base"/*/; do
            [ -d "$prof" ] || continue
            ff=$(( ff + $(remove_dir_contents "$prof/cache2") ))
            ff=$(( ff + $(remove_dir_contents "$prof/OfflineCache") ))
            ff=$(( ff + $(remove_dir_contents "$prof/startupCache") ))
        done
        if [ "$ff" -gt 0 ]; then
            printf "${DGREEN}    Firefox: %s${NC}\n" "$(format_bytes "$ff")"
        fi
        freed=$(( freed + ff ))
    fi

    # ── Edge ──────────────────────────────────────────────────
    local edge_base="$HOME/Library/Application Support/Microsoft Edge"
    if [ -d "$edge_base" ]; then
        local ef=0
        for prof in "$edge_base/Default" "$edge_base"/Profile\ */; do
            [ -d "$prof" ] || continue
            for cd in Cache "Cache2" "Code Cache" GPUCache; do
                ef=$(( ef + $(remove_dir_contents "$prof/$cd") ))
            done
        done
        if [ "$ef" -gt 0 ]; then
            printf "${DGREEN}    Edge: %s${NC}\n" "$(format_bytes "$ef")"
        fi
        freed=$(( freed + ef ))
    fi

    TOTAL_FREED=$(( TOTAL_FREED + freed ))
    record_result "瀏覽器快取 / Browser Cache" "$freed"
    printf "${GREEN}  [v] ${WHITE}瀏覽器快取合計: ${YELLOW}%s${NC}\n" "$(format_bytes "$freed")"
}

clear_app_cache() {
    task_start "App 快取" "App Cache"
    local freed=0

    # ── Discord ────────────────────────────────────────────────
    local discord="$HOME/Library/Application Support/discord"
    if [ -d "$discord" ]; then
        local df=0
        for cd in Cache "Code Cache" GPUCache blob_storage; do
            df=$(( df + $(remove_dir_contents "$discord/$cd") ))
        done
        if [ "$df" -gt 0 ]; then
            echo ""; printf "${DGREEN}    Discord: %s${NC}\n" "$(format_bytes "$df")"
        fi
        freed=$(( freed + df ))
    fi

    # ── Slack ──────────────────────────────────────────────────
    local slack="$HOME/Library/Application Support/Slack"
    if [ -d "$slack" ]; then
        local sf=0
        for cd in Cache "Code Cache" GPUCache; do
            sf=$(( sf + $(remove_dir_contents "$slack/$cd") ))
        done
        if [ "$sf" -gt 0 ]; then printf "${DGREEN}    Slack: %s${NC}\n" "$(format_bytes "$sf")"; fi
        freed=$(( freed + sf ))
    fi

    # ── Zoom ───────────────────────────────────────────────────
    local zoom="$HOME/Library/Application Support/zoom.us"
    if [ -d "$zoom" ]; then
        local zf=0
        zf=$(( zf + $(remove_dir_contents "$zoom/Cache") ))
        zf=$(( zf + $(remove_dir_contents "$HOME/Library/Logs/zoom.us") ))
        if [ "$zf" -gt 0 ]; then printf "${DGREEN}    Zoom: %s${NC}\n" "$(format_bytes "$zf")"; fi
        freed=$(( freed + zf ))
    fi

    # ── Microsoft Teams ────────────────────────────────────────
    local teams="$HOME/Library/Application Support/Microsoft/Teams"
    if [ -d "$teams" ]; then
        local tf=0
        for cd in Cache "blob_storage" "Code Cache" GPUCache; do
            tf=$(( tf + $(remove_dir_contents "$teams/$cd") ))
        done
        if [ "$tf" -gt 0 ]; then printf "${DGREEN}    Teams: %s${NC}\n" "$(format_bytes "$tf")"; fi
        freed=$(( freed + tf ))
    fi

    # ── Spotify ────────────────────────────────────────────────
    local spotify="$HOME/Library/Caches/com.spotify.client"
    if [ -d "$spotify/Data" ]; then
        local spf
        spf=$(remove_dir_contents "$spotify/Data")
        if [ "$spf" -gt 0 ]; then printf "${DGREEN}    Spotify: %s${NC}\n" "$(format_bytes "$spf")"; fi
        freed=$(( freed + spf ))
    fi

    # ── Homebrew ───────────────────────────────────────────────
    local brew_cache="$HOME/Library/Caches/Homebrew"
    if [ -d "$brew_cache" ]; then
        local bf
        bf=$(remove_dir_contents "$brew_cache")
        if [ "$bf" -gt 0 ]; then printf "${DGREEN}    Homebrew: %s${NC}\n" "$(format_bytes "$bf")"; fi
        freed=$(( freed + bf ))
    fi

    if [ "$freed" -eq 0 ]; then
        echo ""
        print_c "  [v] 未找到相關 App / No supported apps found" "$GRAY"
    fi

    TOTAL_FREED=$(( TOTAL_FREED + freed ))
    record_result "App 快取 / App Cache" "$freed"
    printf "${GREEN}  [v] ${WHITE}App 快取合計: ${YELLOW}%s${NC}\n" "$(format_bytes "$freed")"
}

clear_xcode() {
    task_start "Xcode 快取" "Xcode DerivedData"
    local derived="$HOME/Library/Developer/Xcode/DerivedData"

    if [ ! -d "$derived" ]; then
        task_skip "未安裝 Xcode / Xcode not found"
        record_result "Xcode 快取 / Xcode" 0
        return
    fi

    local size
    size=$(get_dir_size_bytes "$derived")
    echo ""
    printf "${YELLOW}  !! DerivedData 約 %s，清除後下次 Build 需重新編譯（需數分鐘）${NC}\n" "$(format_bytes "$size")"
    printf "${YELLOW}     確認清除? [Y/N]: ${NC}"
    read -r confirm
    case "$confirm" in
        [Yy]|是)
            local freed
            freed=$(remove_dir_contents "$derived")
            TOTAL_FREED=$(( TOTAL_FREED + freed ))
            record_result "Xcode 快取 / Xcode DerivedData" "$freed"
            task_done "$freed"
            ;;
        *)
            task_skip "使用者取消 / Cancelled"
            record_result "Xcode 快取 / Xcode DerivedData" 0
            ;;
    esac
}

clear_ds_store() {
    task_start ".DS_Store 隱藏檔" ".DS_Store Files"
    local freed=0 count=0 size

    while IFS= read -r -d '' f; do
        size=$(stat -f%z "$f" 2>/dev/null || echo 0)
        rm -f "$f" 2>/dev/null && {
            freed=$(( freed + size ))
            count=$(( count + 1 ))
        }
    done < <(find "$HOME" -name ".DS_Store" -print0 2>/dev/null)

    TOTAL_FREED=$(( TOTAL_FREED + freed ))
    record_result ".DS_Store 隱藏檔" "$freed"
    if [ "$count" -gt 0 ]; then
        task_done "$freed" "已刪除 $count 個檔案 / Removed $count files"
    else
        task_done 0
    fi
}

clear_downloads_temp() {
    task_start "下載暫存檔" "Downloads Temp Files"
    local dl="$HOME/Downloads"

    if [ ! -d "$dl" ]; then
        task_skip "找不到下載資料夾 / Downloads folder not found"
        record_result "下載暫存 / Downloads Temp" 0
        return
    fi

    local freed=0 size
    # 只清已知的暫存副檔名，絕對不清其他檔案
    # Only known temp extensions — never arbitrary files
    for pat in "*.tmp" "*.part" "*.crdownload" "*.download" "*.opdownload"; do
        while IFS= read -r -d '' f; do
            size=$(stat -f%z "$f" 2>/dev/null || echo 0)
            rm -f "$f" 2>/dev/null && freed=$(( freed + size ))
        done < <(find "$dl" -maxdepth 2 -name "$pat" -print0 2>/dev/null)
    done

    TOTAL_FREED=$(( TOTAL_FREED + freed ))
    record_result "下載暫存 / Downloads Temp" "$freed"
    task_done "$freed"
}

# ============================================================
# SECTION 6: ORCHESTRATION / 協調執行
# ============================================================

run_task() {
    case $1 in
        1) clear_user_caches ;;
        2) clear_user_logs ;;
        3) empty_trash ;;
        4) clear_browser_cache ;;
        5) clear_app_cache ;;
        6) clear_xcode ;;
        7) clear_ds_store ;;
        8) clear_downloads_temp ;;
    esac
}

invoke_full_clean() {
    show_header
    print_c "  開始全面清理... / Starting Full Clean..." "$GREEN"
    print_c "  ─────────────────────────────────────────────────────" "$GRAY"
    echo ""

    for i in 1 2 4 5 7 8; do
        run_task $i
    done

    # 資源回收筒 — 單獨詢問
    echo ""
    local trash_size
    trash_size=$(get_dir_size_bytes "$HOME/.Trash")
    if [ "$trash_size" -gt 0 ]; then
        printf "${YELLOW}  偵測到資源回收筒有 %s，是否清空? [Y/N]: ${NC}" "$(format_bytes "$trash_size")"
        read -r ans
        case "$ans" in [Yy]|是) run_task 3 ;; esac
    fi

    # Xcode — 偵測到才詢問
    local derived="$HOME/Library/Developer/Xcode/DerivedData"
    if [ -d "$derived" ]; then
        echo ""
        local xsize
        xsize=$(get_dir_size_bytes "$derived")
        printf "${YELLOW}  偵測到 Xcode DerivedData (%s)，是否清除? [Y/N]: ${NC}" "$(format_bytes "$xsize")"
        read -r ans
        case "$ans" in [Yy]|是) run_task 6 ;; esac
    fi

    show_summary
}

invoke_selective_clean() {
    show_header
    show_selective_menu
    read -r input

    local upper_input
    upper_input=$(echo "$input" | tr '[:lower:]' '[:upper:]')
    local selected=()

    if [ "$upper_input" = "A" ]; then
        selected=(1 2 3 4 5 6 7 8)
    else
        IFS=',' read -ra parts <<< "$input"
        for part in "${parts[@]}"; do
            local n
            n=$(echo "$part" | tr -d ' ')
            case "$n" in
                [1-8]) selected+=("$n") ;;
            esac
        done
    fi

    if [ ${#selected[@]} -eq 0 ]; then
        print_c "  未選擇任何項目 / No items selected." "$RED"
        sleep 2
        return
    fi

    echo ""
    print_c "  開始選擇性清理... / Starting Selective Clean..." "$GREEN"
    print_c "  ─────────────────────────────────────────────────────" "$GRAY"
    echo ""

    for n in "${selected[@]}"; do
        run_task "$n"
    done

    show_summary
}

# ============================================================
# SECTION 7: SUMMARY / 清理結果
# ============================================================

show_summary() {
    echo ""
    print_c "  +========================================================+" "$CYAN"
    print_c "  |              清理完成！/ Cleaning Complete!            |" "$CYAN"
    print_c "  +========================================================+" "$CYAN"
    echo ""
    printf "${WHITE}  總共釋放 / Total Freed: ${YELLOW}%s${NC}\n" "$(format_bytes "$TOTAL_FREED")"
    echo ""
    print_c "  項目明細 / Breakdown:" "$CYAN"
    print_c "  ─────────────────────────────────────────────────────" "$GRAY"

    for i in "${!RESULT_NAMES[@]}"; do
        local name="${RESULT_NAMES[$i]}" freed="${RESULT_FREED[$i]}" color="$GRAY"
        [ "$freed" -gt 104857600 ] && color="$YELLOW"
        [ "$freed" -gt 0 ] && [ "$freed" -le 104857600 ] && color="$WHITE"
        printf "${color}    %-36s %12s${NC}\n" "$name" "$(format_bytes "$freed")"
    done

    print_c "  ─────────────────────────────────────────────────────" "$GRAY"
    echo ""
    if   [ "$TOTAL_FREED" -gt 1073741824 ]; then
        print_c "  ★★ 釋放超過 1GB！系統應明顯更順暢！" "$GREEN"
    elif [ "$TOTAL_FREED" -gt 104857600 ]; then
        print_c "  ★  清理成功！釋放了可觀的空間。" "$GREEN"
    else
        print_c "  ✓  清理完成。系統狀態良好。" "$GREEN"
    fi
    echo ""
}

# ============================================================
# SECTION 8: MAIN LOOP / 主程式迴圈
# ============================================================

while true; do
    TOTAL_FREED=0
    RESULT_NAMES=()
    RESULT_FREED=()

    show_header
    show_main_menu
    read -r choice

    choice_upper=$(echo "$choice" | tr '[:lower:]' '[:upper:]')

    case "$choice_upper" in
        1)
            invoke_full_clean
            printf "${GRAY}  按 Enter 返回選單 / Press Enter...${NC}"
            read -r
            ;;
        2)
            invoke_selective_clean
            printf "${GRAY}  按 Enter 返回選單 / Press Enter...${NC}"
            read -r
            ;;
        3)
            show_system_info
            ;;
        Q|QUIT|EXIT|離開)
            echo ""
            print_c "  感謝使用！再見！/ Thank you! Goodbye!" "$CYAN"
            echo ""
            sleep 1
            exit 0
            ;;
        *)
            print_c "  無效選項，請重試 / Invalid choice." "$RED"
            sleep 1
            ;;
    esac
done
