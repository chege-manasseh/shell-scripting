#!/bin/bash
# =============================================================================
# LIBRARY MANAGEMENT SYSTEM  — Shell Scripting Course Project
# =============================================================================



# Flat-file pipe-delimited databases, log file, backup directory
BOOKS="books.db"          
USERS="users.db"         
BORROW="borrow.db"        
LOGFILE="library.log"    
BACKUP_DIR="backup"       
ADMINPASS="admin123"      
SCRIPT_VERSION="2.0"      # Version string shown on the main header
SCRIPT_DATE="2026-04-07"  # Last updated date

# Delimiter used in all flat-file records (pipe character)
DELIM="|"

# =============================================================================
# INITIALIZATION
# Creates all data files and the backup directory if they do not exist,
# then verifies write permission on each file before proceeding.
# =============================================================================
init_files() {
    [ ! -f "$BOOKS" ]   && touch "$BOOKS"
    [ ! -f "$USERS" ]   && touch "$USERS"
    [ ! -f "$BORROW" ]  && touch "$BORROW"
    [ ! -f "$LOGFILE" ] && touch "$LOGFILE"
    [ ! -d "$BACKUP_DIR" ] && mkdir -p "$BACKUP_DIR"

    [ ! -w "$BOOKS" ]   && { echo "ERROR: Cannot write to $BOOKS. Check permissions.";   exit 1; }
    [ ! -w "$USERS" ]   && { echo "ERROR: Cannot write to $USERS. Check permissions.";   exit 1; }
    [ ! -w "$BORROW" ]  && { echo "ERROR: Cannot write to $BORROW. Check permissions.";  exit 1; }
    [ ! -w "$LOGFILE" ] && { echo "ERROR: Cannot write to $LOGFILE. Check permissions."; exit 1; }
}


# Appends a timestamped log entry: "YYYY-MM-DD HH:MM:SS | user: <name> | <message>"
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | user: $(whoami) | $1" >> "$LOGFILE"
}


print_header() {
    clear
    echo "============================================================"
    echo "     LIBRARY MANAGEMENT SYSTEM  v${SCRIPT_VERSION}"
    echo "     Last updated: ${SCRIPT_DATE}"
    echo "============================================================"
}

print_line() {
    echo "------------------------------------------------------------"
}

pause() {
    echo ""
    read -rp "Press ENTER to continue..."
}


# show_system_info: uname, whoami, hostname, df -h, free -h
show_system_info() {

    print_header
    echo "  SYSTEM INFORMATION"
    print_line
    echo ""
    echo "  OS / Kernel  : $(uname -a)"
    echo "  Current User : $(whoami)"
    echo "  Hostname     : $(hostname)"
    echo "  Uptime       : $(uptime -p 2>/dev/null || uptime)"
    echo ""
    print_line
    echo "  DISK USAGE (df -h)"
    print_line
    df -h
    echo ""
    print_line
    echo "  MEMORY USAGE (free -h)"
    print_line
    free -h
    echo ""

    pause
}


show_process_info() {

    print_header
    echo "  PROCESS MANAGEMENT"
    print_line
    echo ""
    echo "  Top 15 running processes (by CPU usage):"
    echo ""

    ps aux --sort=-%cpu | head -16

    echo ""
    print_line
    echo "  Search for a specific process:"
    read -rp "  Enter process name (or press ENTER to skip): " proc_name

    if [ -n "$proc_name" ]; then
        echo ""
        echo "  Results for: $proc_name"
        print_line
        # pgrep lists PIDs; ps -p shows details for those PIDs
        ps -p "$(pgrep -d',' "$proc_name" 2>/dev/null)" 2>/dev/null \
            || echo "  No process found with that name."

    fi

    pause
}


# =============================================================================
# BOOK MANAGEMENT
# Functions: add_book, list_books, search_book, update_book, delete_book
# =============================================================================
add_book() {

    while true; do

        print_header
        echo "  ADD NEW BOOK"
        print_line

        read -rp "  Enter Book ID (e.g. B001): " id

        if grep -q "^${id}${DELIM}" "$BOOKS"; then
            echo "  ERROR: Book ID '$id' already exists."
            read -rp "  Try a different ID? (yes/no): " retry
            [ "$retry" = "yes" ] && continue || break
        fi

        read -rp "  Enter Title    : " title
        read -rp "  Enter Author   : " author
        read -rp "  Enter Category : " category

        if [ -z "$id" ] || [ -z "$title" ] || [ -z "$author" ] || [ -z "$category" ]; then
            echo "  ERROR: All fields are required."
            read -rp "  Try again? (yes/no): " retry
            [ "$retry" = "yes" ] && continue || break
        fi

        # Append a new record to books.db (append redirection >>)
        echo "${id}${DELIM}${title}${DELIM}${author}${DELIM}${category}${DELIM}available" >> "$BOOKS"

        log_action "Book added: ID=$id, Title=$title"
        echo ""
        echo "  Book '$title' added successfully."

        echo ""
        read -rp "  Add another book? (yes/no): " again
        [ "$again" = "yes" ] || break

    done

}

list_books() {

    print_header
    echo "  BOOK LIST"
    print_line

    # Check if the database is empty 
    if [ ! -s "$BOOKS" ]; then
        echo "  No books found in the database."
        pause
        return
    fi

    printf "  %-8s %-35s %-20s %-12s %s\n" "ID" "TITLE" "AUTHOR" "CATEGORY" "STATUS"
    print_line
    # STATUS column is color-coded: green = available, red = borrowed, yellow = other
    awk -F'|' '{
        if ($5 == "available") {
            color = "\033[32m"
        } else if ($5 == "borrowed") {
            color = "\033[31m"
        } else {
            color = "\033[33m"
        }
        reset = "\033[0m"
        printf "  %-8s %-35s %-20s %-12s %s%s%s\n", $1, $2, $3, $4, color, $5, reset
    }' "$BOOKS"

    echo ""
    echo "  Total records: $(wc -l < "$BOOKS")"


    pause
}

search_book() {

    print_header
    echo "  SEARCH BOOKS"
    print_line
    read -rp "  Enter keyword (title, author, category, or ID): " key

    if [ -z "$key" ]; then
        echo "  Please enter a search keyword."
        pause
        return
    fi

    echo ""
    echo "  Results for: '$key'"
    print_line

    # grep -i : case-insensitive search across all fields
    results=$(grep -i "$key" "$BOOKS")

    if [ -z "$results" ]; then
        echo "  No books matched your search."
    else
        echo "$results" | awk -F'|' '{
            printf "  %-8s %-35s %-20s %-12s %s\n", $1, $2, $3, $4, $5
        }'
    fi

    pause
}

delete_book() {

    print_header
    echo "  DELETE BOOK"
    print_line
    read -rp "  Enter Book ID to delete: " id

    # Decision making: check the book exists first
    if ! grep -q "^${id}${DELIM}" "$BOOKS"; then
        echo "  ERROR: Book ID '$id' not found."
        pause
        return
    fi

    # Safety check: don't delete if the book is currently borrowed
    if grep -q "${DELIM}${id}${DELIM}" "$BORROW"; then
        echo "  ERROR: Cannot delete — this book is currently borrowed."
        pause
        return
    fi

    # Capture the full record now — once sed removes the line the data is gone.
    record=$(grep "^${id}${DELIM}" "$BOOKS")
    book_title=$(echo "$record"  | cut -d'|' -f2)
    book_author=$(echo "$record" | cut -d'|' -f3)
    book_cat=$(echo "$record"    | cut -d'|' -f4)
    book_status=$(echo "$record" | cut -d'|' -f5)

    # Confirm before deleting
    echo ""
    echo "  Book to be deleted:"
    echo "    Title    : $book_title"
    echo "    Author   : $book_author"
    echo "    Category : $book_cat"
    echo "    Status   : $book_status"
    echo ""
    read -rp "  Are you sure you want to delete ID '$id'? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log_action "Book delete CANCELLED: ID=$id, Title=$book_title"
        echo "  Delete cancelled."
        pause
        return
    fi

    sed -i "/^${id}${DELIM}/d" "$BOOKS"

    log_action "Book DELETED: ID=$id | Title=$book_title | Author=$book_author | Category=$book_cat | WasStatus=$book_status"
    echo "  Book '$book_title' (ID: $id) removed successfully."

    pause
}

update_book() {

    print_header
    echo "  UPDATE BOOK"
    print_line
    read -rp "  Enter Book ID to update: " id

    record=$(grep "^${id}${DELIM}" "$BOOKS")

    if [ -z "$record" ]; then
        echo "  ERROR: Book ID '$id' not found."
        pause
        return
    fi

    # Show the current values for reference
    echo ""
    echo "  Current record:"
    echo "$record" | awk -F'|' '{
        print "    ID       : " $1
        print "    Title    : " $2
        print "    Author   : " $3
        print "    Category : " $4
        print "    Status   : " $5
    }'
    echo ""

    read -rp "  New Title    (ENTER to keep current): " title
    read -rp "  New Author   (ENTER to keep current): " author
    read -rp "  New Category (ENTER to keep current): " category

    old_title=$(echo "$record"    | cut -d'|' -f2)
    old_author=$(echo "$record"   | cut -d'|' -f3)
    old_category=$(echo "$record" | cut -d'|' -f4)
    old_status=$(echo "$record"   | cut -d'|' -f5)

    # ${var:-default} keeps the current value if the user presses ENTER
    title="${title:-$old_title}"
    author="${author:-$old_author}"
    category="${category:-$old_category}"

    echo "  Valid statuses: available | borrowed | lost | damaged | maintenance"
    echo "  Current status: $old_status"
    read -rp "  New Status   (ENTER to keep current): " new_status
    new_status="${new_status:-$old_status}"

    case "$new_status" in
        available|borrowed|lost|damaged|maintenance) ;;
        *)
            echo "  WARNING: '$new_status' is not a recognised status."
            echo "  Keeping current status: $old_status"
            new_status="$old_status"
            ;;
    esac

    # If a borrowed book is manually set to a non-borrowed status,
    # remove its borrow record so the data stays consistent.
    if [ "$old_status" = "borrowed" ] && [ "$new_status" != "borrowed" ]; then
        if grep -q "${DELIM}${id}${DELIM}" "$BORROW"; then
            sed -i "/${DELIM}${id}${DELIM}/d" "$BORROW"
            echo "  NOTE: Borrow record for '$id' removed (status changed from borrowed)."
        fi
    fi

    sed -i "/^${id}${DELIM}/d" "$BOOKS"
    echo "${id}${DELIM}${title}${DELIM}${author}${DELIM}${category}${DELIM}${new_status}" >> "$BOOKS"

    log_action "Book updated: ID=$id, Status=$old_status->$new_status"
    echo "  Book '$id' updated successfully (status: $old_status -> $new_status)."

    pause
}



sync_overdue_status() {

    print_header
    echo "  SYNC OVERDUE STATUS"
    print_line
    echo ""
    echo "  Scanning borrow records and updating books past their due date..."
    echo ""

    if [ ! -s "$BORROW" ]; then
        echo "  No active borrow records found."
        pause
        return
    fi

    today=$(date +%Y-%m-%d)  
    updated=0                 
    already=0                 

    while IFS='|' read -r uname bid bdate ddate; do

        # YYYY-MM-DD strings compare lexicographically, so > works for date comparison.
        if [[ "$today" > "$ddate" ]]; then

            current_status=$(grep "^${bid}${DELIM}" "$BOOKS" | awk -F'|' '{print $5}')

            if [ "$current_status" = "overdue" ]; then
                # Already marked — nothing to do
                echo "  [already overdue] Book $bid (due: $ddate)"
                (( already++ ))
            else
                sed -i "s/^${bid}${DELIM}\(.*\)${DELIM}${current_status}$/${bid}${DELIM}\1${DELIM}overdue/" "$BOOKS"
                echo "  [updated -> overdue] Book $bid — borrower $uname, due $ddate"
                log_action "Book $bid marked overdue: was $current_status, due=$ddate, borrower=$uname"
                (( updated++ ))
            fi
        fi

    done < "$BORROW"

    echo ""
    print_line
    echo "  Done.  Updated: $updated  |  Already overdue: $already"
    echo ""
    echo "  TIP: Run 'return_book' to return an overdue book."
    echo "       Its status will be reset to 'available' automatically."

    pause
}

# =============================================================================
# USER MANAGEMENT
# Functions: register_user, list_users, delete_user
# users.db format: username|Name|Email|Role|PasswordHash
# =============================================================================

register_user() {
    print_header
    echo "  REGISTER NEW USER"
    print_line

    # Username is the primary key — what the user authenticates with.
    read -rp "  Choose a Username         : " uname
    read -rp "  Enter Full Name           : " name
    read -rp "  Enter Email Address       : " email

    if [ -z "$uname" ] || [ -z "$name" ] || [ -z "$email" ]; then
        echo "  ERROR: All fields are required."
        pause
        return
    fi

    if [[ ! "$uname" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "  ERROR: Username may only contain letters, digits, _ or -."
        pause
        return
    fi

    if grep -q "^${uname}${DELIM}" "$USERS"; then
        echo "  ERROR: Username '$uname' is already taken. Please choose another."
        pause
        return
    fi

    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "  WARNING: '$email' does not look like a valid email address."
        read -rp "  Continue anyway? (yes/no): " proceed
        [ "$proceed" != "yes" ] && { pause; return; }
    fi

    # Password is stored as a sha256 hash — never in plain text.
    # Loop until the user enters a valid, matching password.
    while true; do
        echo ""
        read -rsp "  Enter Password            : " pass1
        echo ""

        if [ -z "$pass1" ]; then
            echo "  ERROR: Password cannot be empty. Please try again."
            continue
        fi

        read -rsp "  Confirm Password          : " pass2
        echo ""

        if [ "$pass1" != "$pass2" ]; then
            echo "  ERROR: Passwords do not match. Please try again."
            continue
        fi

        break
    done

    pass_hash=$(echo -n "$pass1" | sha256sum | awk '{print $1}')

    # Record format: username|Name|Email|Role|PasswordHash
    echo "${uname}${DELIM}${name}${DELIM}${email}${DELIM}member${DELIM}${pass_hash}" >> "$USERS"

    log_action "User registered: username=$uname, Name=$name"
    echo ""
    echo "  Account created for '$name'. You can now log in as: $uname"

    pause
}

list_users() {

    print_header
    echo "  REGISTERED USERS"
    print_line

    if [ ! -s "$USERS" ]; then
        echo "  No users registered yet."
        pause
        return
    fi

    # AWK hides field 5 (the password hash) — only fields 1-4 are displayed.
    printf "  %-16s %-25s %-30s %s\n" "USERNAME" "NAME" "EMAIL" "ROLE"
    print_line
    awk -F'|' '{
        printf "  %-16s %-25s %-30s %s\n", $1, $2, $3, $4
    }' "$USERS"

    echo ""
    echo "  Total users: $(wc -l < "$USERS")"

    pause
}

delete_user() {

    print_header
    echo "  DELETE USER"
    print_line
    read -rp "  Enter Username to delete: " uname

    if ! grep -q "^${uname}${DELIM}" "$USERS"; then
        echo "  ERROR: Username '$uname' not found."
        pause
        return
    fi

    if grep -q "^${uname}${DELIM}" "$BORROW"; then
        echo "  ERROR: Cannot delete — user has books that are still borrowed."
        pause
        return
    fi

    user_name=$(grep "^${uname}${DELIM}" "$USERS" | awk -F'|' '{print $2}')
    read -rp "  Confirm delete '$uname' ($user_name)? (yes/no): " confirm
    [ "$confirm" != "yes" ] && { echo "  Delete cancelled."; pause; return; }

    sed -i "/^${uname}${DELIM}/d" "$USERS"

    log_action "User deleted: username=$uname, Name=$user_name"
    echo "  User '$uname' removed."

    pause
}

# =============================================================================
# BORROW / RETURN SYSTEM
# Functions: borrow_book, return_book, list_borrowed, sync_overdue_status
# borrow.db format: username|BookID|BorrowDate|DueDate
# =============================================================================

borrow_book() {

    print_header
    echo "  BORROW A BOOK"
    print_line

    if [ -n "$CURRENT_USER" ]; then
        uname="$CURRENT_USER"
        echo "  Borrowing as: $CURRENT_USER_NAME ($uname)"
    else
        read -rp "  Enter Username : " uname
    fi
    read -rp "  Enter Book ID  : " bid

    if ! grep -q "^${uname}${DELIM}" "$USERS"; then
        echo "  ERROR: Username '$uname' not found."
        pause
        return
    fi

    book=$(grep "^${bid}${DELIM}" "$BOOKS")
    if [ -z "$book" ]; then
        echo "  ERROR: Book ID '$bid' not found."
        pause
        return
    fi

    status=$(echo "$book" | awk -F'|' '{print $5}')

    if [ "$status" != "available" ]; then
        echo "  ERROR: Book '$bid' is currently not available."
        pause
        return
    fi

    # Enforce a 3-book borrowing limit per user.
    borrow_count=$(grep -c "^${uname}${DELIM}" "$BORROW" 2>/dev/null)
    borrow_count=${borrow_count:-0}
    if [ "$borrow_count" -ge 3 ]; then
        echo "  ERROR: '$uname' already has 3 borrowed books (maximum reached)."
        pause
        return
    fi

    borrow_date=$(date +%Y-%m-%d)
    due_date=$(date -d "+14 days" +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)

    echo "${uname}${DELIM}${bid}${DELIM}${borrow_date}${DELIM}${due_date}" >> "$BORROW"

    # Update book status from 'available' to 'borrowed'.
    sed -i "s/^${bid}${DELIM}\(.*\)${DELIM}available$/${bid}${DELIM}\1${DELIM}borrowed/" "$BOOKS"

    log_action "Book borrowed: BookID=$bid by username=$uname, Due=$due_date"
    echo "  Book borrowed successfully. Due date: $due_date"

    pause
}

return_book() {

    print_header
    echo "  RETURN A BOOK"
    print_line

    read -rp "  Enter Book ID to return: " bid

    # Check there is an active borrow record for this book
    if ! grep -q "${DELIM}${bid}${DELIM}" "$BORROW"; then
        echo "  ERROR: No active borrow record found for Book '$bid'."
        pause
        return
    fi

    due_date=$(grep "${DELIM}${bid}${DELIM}" "$BORROW" | awk -F'|' '{print $4}')
    today=$(date +%Y-%m-%d)

    # YYYY-MM-DD strings are lexicographically sortable, so > works for date comparison.
    if [[ "$today" > "$due_date" ]]; then
        echo "  NOTE: This book was due on $due_date — it is overdue!"
    fi

    sed -i "/${DELIM}${bid}${DELIM}/d" "$BORROW"

    # Two sed passes reset both 'borrowed' and 'overdue' status back to 'available'.
    sed -i "s/^${bid}${DELIM}\(.*\)${DELIM}borrowed$/${bid}${DELIM}\1${DELIM}available/" "$BOOKS"
    sed -i "s/^${bid}${DELIM}\(.*\)${DELIM}overdue$/${bid}${DELIM}\1${DELIM}available/"  "$BOOKS"

    log_action "Book returned: BookID=$bid on $today"
    echo "  Book '$bid' returned successfully."

    pause
}

list_borrowed() {

    print_header
    echo "  CURRENTLY BORROWED BOOKS"
    print_line

    if [ ! -s "$BORROW" ]; then
        echo "  No books are currently borrowed."
        pause
        return
    fi

    printf "  %-16s %-10s %-14s %-14s %s\n" "USERNAME" "BOOK ID" "BORROW DATE" "DUE DATE" "STATUS"
    print_line

    local RED="\e[31m"
    local GREEN="\e[32m"
    local RESET="\e[0m"
    local today
    today=$(date +%Y-%m-%d)

    while IFS='|' read -r uname bid bdate ddate; do
        if [[ "$today" > "$ddate" ]]; then
            status="${RED}OVERDUE${RESET}"
        else
            status="${GREEN}On time${RESET}"
        fi
        printf "  %-16s %-10s %-14s %-14s %b\n" "$uname" "$bid" "$bdate" "$ddate" "$status"
    done < "$BORROW"

    echo ""
    echo "  Total borrowed: $(wc -l < "$BORROW")"

    pause
}

# =============================================================================
# REPORTS
# Functions: report_total_books
# Uses AWK associative arrays to count books by category.
# =============================================================================

report_total_books() {

    print_header
    echo "  REPORT: TOTAL BOOKS"
    print_line
    echo ""

    total=$(wc -l < "$BOOKS")
    available=$(grep -c "${DELIM}available$" "$BOOKS" 2>/dev/null || echo 0)
    borrowed=$(grep -c "${DELIM}borrowed$"  "$BOOKS" 2>/dev/null || echo 0)

    echo "  Total books    : $total"
    echo "  Available      : $available"
    echo "  Borrowed       : $borrowed"
    echo ""

    # AWK associative array: counts books per category.
    echo "  Books by category:"
    print_line
    awk -F'|' '{
        category[$4]++
    }
    END {
        for (cat in category) {
            printf "  %-20s : %d\n", cat, category[cat]
        }
    }' "$BOOKS"

    pause
}

backup_data() {

    print_header
    echo "  BACKUP SYSTEM DATA"
    print_line

    # Generate a timestamp for the backup folder name
    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_path="${BACKUP_DIR}/${timestamp}"

    mkdir -p "$backup_path"

    cp "$BOOKS"   "${backup_path}/books.db"    2>/dev/null && echo "  Backed up: books.db"
    cp "$USERS"   "${backup_path}/users.db"    2>/dev/null && echo "  Backed up: users.db"
    cp "$BORROW"  "${backup_path}/borrow.db"   2>/dev/null && echo "  Backed up: borrow.db"
    cp "$LOGFILE" "${backup_path}/library.log" 2>/dev/null && echo "  Backed up: library.log"

    echo ""
    echo "  Backup saved to: $backup_path"

    log_action "System backup performed: $backup_path"

    pause
}

restore_data() {

    print_header
    echo "  RESTORE FROM BACKUP"
    print_line

    # List available backups — ls output piped through grep (pipes/filters)
    echo "  Available backups:"
    echo ""

    declare -a backups
    mapfile -t backups < <(ls -1 "$BACKUP_DIR" 2>/dev/null)

    if [ ${#backups[@]} -eq 0 ]; then
        echo "  No backups found in '$BACKUP_DIR'."
        pause
        return
    fi

    for i in "${!backups[@]}"; do
        printf "  %2d) %s\n" $(( i + 1 )) "${backups[$i]}"
    done

    echo ""
    read -rp "  Enter backup number to restore (0 to cancel): " choice

    if [ "$choice" -eq 0 ] 2>/dev/null; then
        echo "  Restore cancelled."
        pause
        return
    fi

    if [ "$choice" -lt 1 ] || [ "$choice" -gt ${#backups[@]} ] 2>/dev/null; then
        echo "  Invalid selection."
        pause
        return
    fi

    selected="${backups[$(( choice - 1 ))]}"
    restore_path="${BACKUP_DIR}/${selected}"

    read -rp "  Restore from '$selected'? This will overwrite current data. (yes/no): " confirm
    [ "$confirm" != "yes" ] && { echo "  Restore cancelled."; pause; return; }

    cp "${restore_path}/books.db"    "$BOOKS"   2>/dev/null && echo "  Restored: books.db"
    cp "${restore_path}/users.db"    "$USERS"   2>/dev/null && echo "  Restored: users.db"
    cp "${restore_path}/borrow.db"   "$BORROW"  2>/dev/null && echo "  Restored: borrow.db"

    log_action "Data restored from backup: $restore_path"
    echo ""
    echo "  Data restored successfully from: $selected"

    pause
}

view_logs() {

    print_header
    echo "  ACTIVITY LOG VIEWER"
    print_line
    echo ""

    if [ ! -s "$LOGFILE" ]; then
        echo "  Log file is empty."
        pause
        return
    fi

    echo "  Options:"
    echo "  1) View last 20 entries"
    echo "  2) View full log"
    echo "  3) Search log"
    echo "  4) Clear log"
    echo "  0) Back"
    echo ""
    read -rp "  Choice: " log_choice

    case $log_choice in
        1)
            echo ""
            echo "  Last 20 log entries:"
            print_line
            tail -20 "$LOGFILE"
            ;;
        2)
            cat "$LOGFILE" | less
            ;;
        3)
            read -rp "  Enter keyword to search: " log_key
            echo ""
            echo "  Log entries matching '$log_key':"
            print_line
            grep --color=auto -i "$log_key" "$LOGFILE" || echo "  No matches found."
            ;;
        4)
            read -rp "  Clear entire log? (yes/no): " clr
            if [ "$clr" = "yes" ]; then
                > "$LOGFILE"
                echo "  Log cleared."
            fi
            ;;
        0) return ;;
        *) echo "  Invalid option." ;;
    esac

    pause
}



show_resource_management() {

    print_header
    echo "  RESOURCE MANAGEMENT "
    print_line
    echo ""

    echo "  1. DISK USAGE of library data files:"
    print_line
    du -sh "$BOOKS" "$USERS" "$BORROW" "$LOGFILE" "$BACKUP_DIR" 2>/dev/null
    echo ""

    echo "  2. FILE LINE COUNTS (wc -l):"
    print_line
    wc -l "$BOOKS" "$USERS" "$BORROW" 2>/dev/null
    echo ""

    echo "  3. CURRENT DIRECTORY LISTING (ls -lh):"
    print_line
    ls -lh "$BOOKS" "$USERS" "$BORROW" "$LOGFILE" 2>/dev/null
    echo ""

    echo "  4. OPEN FILE DESCRIPTORS for this script (lsof):"
    print_line
    lsof -p $$ 2>/dev/null | head -10 || echo "  (lsof not available)"
    echo ""

    pause
}

# =============================================================================
# LOGIN & SESSION MANAGEMENT
# Functions: user_login, user_menu, user_view_borrowed, admin_login
# =============================================================================

user_login() {

    print_header
    echo "  USER LOGIN"
    print_line
    echo ""

    read -rp "  Enter your Username: " uname

    if ! grep -q "^${uname}${DELIM}" "$USERS"; then
        echo ""
        echo "  Username '$uname' is not registered."
        echo ""
        read -rp "  Would you like to register now? (yes/no): " do_reg
        if [ "$do_reg" = "yes" ]; then
            register_user
        else
            echo "  Login cancelled."
            pause
        fi
        return
    fi

    # Extract field 5 (hash) from the matching users.db record.
    stored_hash=$(grep "^${uname}${DELIM}" "$USERS" | awk -F'|' '{print $5}')

    # If the record has no hash (legacy record), block login.
    if [ -z "$stored_hash" ]; then
        echo ""
        echo "  ERROR: This account has no password set."
        echo "  Please ask the administrator to delete and re-register your account."
        log_action "Login BLOCKED (no password hash): username=$uname"
        pause
        return
    fi

    read -rsp "  Enter Password: " entered_pass
    echo ""

    # Pipeline: echo -n — no trailing newline; sha256sum — digest; awk — strip hash suffix
    entered_hash=$(echo -n "$entered_pass" | sha256sum | awk '{print $1}')

    if [ "$entered_hash" = "$stored_hash" ]; then
        user_name=$(grep "^${uname}${DELIM}" "$USERS" | awk -F'|' '{print $2}')
        echo ""
        echo "  Welcome back, $user_name!"
        log_action "User login successful: username=$uname, Name=$user_name"
        CURRENT_USER="$uname"
        CURRENT_USER_NAME="$user_name"
        user_menu
    else
        echo ""
        echo "  Incorrect password. Access denied."
        log_action "User login FAILED (wrong password): username=$uname"
        pause
    fi

}

user_menu() {

    while true; do

        print_header
        echo "  MEMBER PORTAL  —  Logged in as: $CURRENT_USER_NAME  (username: $CURRENT_USER)"
        print_line
        echo ""
        echo "   1) Search Books"
        echo "   2) View All Books"
        echo "   3) Borrow a Book"
        echo "   4) Return a Book"
        echo "   5) My Borrowed Books"
        echo ""
        echo "   0) Logout"
        print_line
        read -rp "  Choose: " choice

        case $choice in
            1) search_book ;;
            2) list_books ;;
            3) borrow_book ;;
            4) return_book ;;
            5) user_view_borrowed ;;
            0)
                echo "  Goodbye, $CURRENT_USER_NAME!"
                log_action "User logout: ID=$CURRENT_USER"
                CURRENT_USER=""
                CURRENT_USER_NAME=""
                break
                ;;
            *) echo "  Invalid option." ;;
        esac

    done
}

user_view_borrowed() {

    print_header
    echo "  MY BORROWED BOOKS  —  $CURRENT_USER_NAME"
    print_line

    # Filter borrow.db to rows that start with this user's username
    my_borrows=$(grep "^${CURRENT_USER}${DELIM}" "$BORROW")

    if [ -z "$my_borrows" ]; then
        echo ""
        echo "  You have no books currently borrowed."
        pause
        return
    fi

    printf "  %-10s %-35s %-14s %-14s %s\n" "BOOK ID" "TITLE" "BORROW DATE" "DUE DATE" "STATUS"
    print_line

    local RED="\e[31m"
    local GREEN="\e[32m"
    local RESET="\e[0m"
    local today
    today=$(date +%Y-%m-%d)

    while IFS='|' read -r _uid bid bdate ddate; do
        book_title=$(grep "^${bid}${DELIM}" "$BOOKS" | awk -F'|' '{print $2}')
        [ -z "$book_title" ] && book_title="(title not found)"

        if [[ "$today" > "$ddate" ]]; then
            row_status="${RED}OVERDUE${RESET}"
        else
            row_status="${GREEN}On time${RESET}"
        fi

        printf "  %-10s %-35s %-14s %-14s %b\n" \
            "$bid" "$book_title" "$bdate" "$ddate" "$row_status"
    done <<< "$my_borrows"

    echo ""
    echo "  Total borrowed: $(echo "$my_borrows" | wc -l)"

    pause
}

admin_login() {

    print_header
    echo "  ADMIN LOGIN"
    print_line
    echo ""

    read -rsp "  Enter admin password: " pass
    echo ""

    if [ "$pass" = "$ADMINPASS" ]; then
        log_action "Admin login successful"
        admin_menu
    else
        echo "  Incorrect password. Access denied."
        log_action "Admin login FAILED — incorrect password"
        pause
    fi

}

admin_menu() {

    while true; do

        print_header
        echo "  ADMIN MENU"
        print_line
        echo ""
        echo "  --- BOOK MANAGEMENT ---"
        echo "   1) Add Book"
        echo "   2) List Books"
        echo "   3) Search Book"
        echo "   4) Update Book"
        echo "   5) Delete Book"
        echo ""
        echo "  --- USER MANAGEMENT ---"
        echo "   6) Register User"
        echo "   7) List Users"
        echo "   8) Delete User"
        echo ""
        echo "  --- BORROW SYSTEM ---"
        echo "   9) Borrow Book"
        echo "  10) Return Book"
        echo "  11) View Borrowed Books"
        echo ""
        echo "  --- REPORTS & ADMIN ---"
        echo "  12) Book Statistics"
        echo "  13) View Activity Log"
        echo "  14) Backup Data"
        echo "  15) Restore Data"
        echo "  16) System Information"
        echo "  17) Process Management"
        echo "  18) Resource Management"
        echo "  19) Sync Overdue Status"
        echo ""
        echo "   0) Logout"
        print_line
        read -rp "  Enter choice: " choice

        case $choice in
            1)  add_book ;;
            2)  list_books ;;
            3)  search_book ;;
            4)  update_book ;;
            5)  delete_book ;;
            6)  register_user ;;
            7)  list_users ;;
            8)  delete_user ;;
            9)  borrow_book ;;
            10) return_book ;;
            11) list_borrowed ;;
            12) report_total_books ;;
            13) view_logs ;;
            14) backup_data ;;
            15) restore_data ;;
            16) show_system_info ;;
            17) show_process_info ;;
            18) show_resource_management ;;
            19) sync_overdue_status ;;
            0)  echo "  Logged out."; log_action "Admin logged out"; break ;;
            *)  echo "  Invalid option. Please try again." ;;
        esac

    done

}

main_menu() {

    while true; do

        print_header
        echo ""
        echo "  Welcome to the Library Management System"
        echo "  | Linux basics to AWK & shell scripting"
        echo ""
        print_line
        echo "   1) Register (New User)"
        echo "   2) User Login"
        echo "   3) Admin Login"
        echo "   0) Exit"
        print_line
        read -rp "  Choose: " choice

        case $choice in
            1) register_user ;;
            2) user_login ;;
            3) admin_login ;;
            0) echo ""; echo "  Goodbye!"; echo ""; exit 0 ;;
            *) echo "  Invalid option." ;;
        esac

    done

}

init_files
main_menu
