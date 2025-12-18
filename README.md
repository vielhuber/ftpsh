📂 ftpsh 📂

ftpsh is a bash helper for executing shell commands on remote servers via ftp/sftp. with its help you can run any shell command on a remote server that only has ftp/sftp access and php support. this enables for example `git` or `mysqldump` if present on the host. it handles the upload, execution, and cleanup automatically in a secure way.

## how it works

1. **reads configuration** from `.env` file
2. **encodes your command** in base64 to handle special characters safely
3. **creates a temporary php file** with the command
4. **uploads the file** via ftp/sftp to the remote server
5. **executes the file** via http request
6. **outputs the result** to your terminal
7. **cleans up** by deleting the remote and local temporary files

## installation / update

simply download the script:

```bash
mkdir ftpsh
cd ftpsh
wget -O ftpsh.sh https://raw.githubusercontent.com/vielhuber/ftpsh/main/ftpsh.sh
chmod +x ftpsh.sh
```

then create a `.env` file with your credentials:

```bash
cp .env.example .env
nano .env
```

to use `ftpsh` from anywhere instead of `./ftpsh.sh`, create a symlink in your path:

```bash
sudo ln -s $(pwd)/ftpsh.sh /usr/local/bin/ftpsh
```

## configuration

edit the `.env` file with your server credentials:

```env
HOST=your-server.com
PORT=22
USERNAME=your-username
PASSWORD=your-password
REMOTE_PATH="/"
WEB_URL="https://your-server.com"
```

**parameters:**

- `HOST`: ftp/sftp server hostname
- `PORT`: port (22 for sftp, 21 for ftp)
- `USERNAME`: your ftp/sftp username
- `PASSWORD`: your ftp/sftp password
- `REMOTE_PATH`: remote directory path where php files can be executed
- `WEB_URL`: web uRL to access the remote path

## usage

### basic commands

execute any shell command on the remote server:

```bash
ftpsh ls -la
ftpsh pwd
ftpsh php -v
ftpsh whoami
```

### git commands

```bash
ftpsh git status
ftpsh git pull
ftpsh git log --oneline -5
ftpsh git diff
```

### composer commands

```bash
ftpsh composer install
ftpsh composer update
ftpsh composer dump-autoload
```

### complex commands with pipes and redirects

```bash
ftpsh "cat file.txt | grep 'search'"
ftpsh "find . -name '*.php' | wc -l"
ftpsh "du -sh *"
```
