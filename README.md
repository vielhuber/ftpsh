# 🚀 ftpsh 🚀

ftpsh is a bash helper for executing shell commands on remote servers via FTP/SFTP. with its help you can run any shell command on a remote server that only has FTP/SFTP access and PHP support. it handles the upload, execution, and cleanup automatically in a secure way.

## installation

simply download the script:

```bash
wget https://raw.githubusercontent.com/vielhuber/ftpsh/main/ftpsh.sh
chmod +x ftpsh.sh
```

then create a `.env` file with your credentials:

```bash
cp .env.example .env
nano .env
```

## configuration

edit the `.env` file with your server credentials:

```env
HOST=your-server.com
PORT=22
USERNAME=your-username
PASSWORD=your-password
REMOTE_PATH="/"
URL="https://your-server.com"
```

**parameters:**

- `HOST`: FTP/SFTP server hostname
- `PORT`: Port (22 for SFTP, 21 for FTP)
- `USERNAME`: Your FTP/SFTP username
- `PASSWORD`: Your FTP/SFTP password
- `REMOTE_PATH`: Remote directory path where PHP files can be executed
- `URL`: Web URL to access the remote path
- `PROTOCOL` (optional): Protocol to use (`ftp` or `sftp`, auto-detected from port if not set)

## usage

### basic commands

execute any shell command on the remote server:

```bash
./ftpsh.sh ls -la
./ftpsh.sh pwd
./ftpsh.sh php -v
./ftpsh.sh whoami
```

### git commands

```bash
./ftpsh.sh git status
./ftpsh.sh git pull
./ftpsh.sh git log --oneline -5
./ftpsh.sh git diff
```

### composer commands

```bash
./ftpsh.sh composer install
./ftpsh.sh composer update
./ftpsh.sh composer dump-autoload
```

### complex commands with pipes and redirects

```bash
./ftpsh.sh "cat file.txt | grep 'search'"
./ftpsh.sh "find . -name '*.php' | wc -l"
./ftpsh.sh "du -sh *"
```

## how it works

1. **reads configuration** from `.env` file
2. **encodes your command** in base64 to handle special characters safely
3. **creates a temporary PHP file** with the command
4. **uploads the file** via FTP/SFTP to the remote server
5. **executes the file** via HTTP request
6. **outputs the result** to your terminal
7. **cleans up** by deleting the remote and local temporary files

## features

- ✅ supports both FTP and SFTP protocols
- ✅ auto-detects protocol from port number
- ✅ secure base64 encoding for commands with special characters
- ✅ automatic cleanup of temporary files
- ✅ high time and memory limits for long-running commands
- ✅ proper error handling and output redirection
- ✅ environment variables support (HOME, PWD)

## requirements

- bash shell
- curl (usually pre-installed)
- FTP/SFTP access to remote server
- PHP support on remote server
- web access to the remote directory
