# Library Management System

A command-line library management system written in Bash, developed as a shell scripting course project covering 

## Getting Started

```bash
chmod +x library.sh
./library.sh
```

Requires Bash 4+ and standard UNIX utilities (`awk`, `sed`, `grep`, `sha256sum`, `date`).

## Features

| Area | Capabilities |
|---|---|
| Books | Add (multi-entry loop), list, search, update status, delete |
| Users | Register, list, delete; passwords stored as SHA-256 hashes |
| Borrow/Return | 3-book limit per user, 14-day due date, overdue detection |
| Reports | Total book count with breakdown by category |
| Logs | View last N entries, full log, keyword search, clear |
| Backup/Restore | Timestamped backup folders, numbered restore menu |
| System | Disk/memory/process info, resource management view |

## Default Credentials

| Role | Login |
|---|---|
| Admin | password: `admin123` |
| Member | register an account from the main menu |

## Data Files

All data is stored as pipe-delimited flat files in the working directory:

| File | Format |
|---|---|
| `books.db` | `BookID\|Title\|Author\|Category\|Status` |
| `users.db` | `username\|Name\|Email\|Role\|PasswordHash` |
| `borrow.db` | `username\|BookID\|BorrowDate\|DueDate` |
| `library.log` | Timestamped audit log |
| `backup/` | Timestamped backup folders |

Book statuses: `available`, `borrowed`, `overdue`, `lost`, `damaged`, `maintenance`.

## Security Notes

- Member passwords are hashed with `sha256sum` before storage — plain-text passwords are never written to disk.
- The admin password (`ADMINPASS`) is stored in plain text in the script. Change it before deploying in any shared environment.
