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

```sh
mkdir ftpsh
cd ftpsh
wget -O ftpsh.sh https://raw.githubusercontent.com/vielhuber/ftpsh/main/ftpsh.sh
chmod +x ftpsh.sh
```

then create a `.env` file with your credentials:

```sh
cp .env.example .env
nano .env
```

to use `ftpsh` from anywhere instead of `./ftpsh.sh`, create a symlink in your path:

```sh
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
- `WEB_URL`: web url to access the remote path

additionally environment variables that are already set will be used.

## usage

### basic commands

execute any shell command on the remote server:

```sh
ftpsh ls -la
ftpsh pwd
ftpsh php -v
ftpsh whoami
```

### git commands

```sh
ftpsh git status
ftpsh git pull
ftpsh git log --oneline -5
ftpsh git diff
ftpcall "git add -A . && git commit -m \".\" && git push"
```

### mysqldump

```sh
ftpsh "mysqldump -h xxx --port 3306 -u xxx -p\"xxx\" --routines xxx" > dump.sql
```

### composer commands

```sh
ftpsh composer install
ftpsh composer update
ftpsh composer dump-autoload
```

### complex commands with pipes and redirects

```sh
ftpsh "cat file.txt | grep 'search'"
ftpsh "find . -name '*.php' | wc -l"
ftpsh "du -sh *"
```

### adjust git config to shared host

```sh
ftpsh git config pack.packSizeLimit 20m
ftpsh git config pack.windowMemory 10m
ftpsh git config core.preloadindex false
ftpsh git config user.name "David Vielhuber"
ftpsh git config user.email "david@vielhuber.de"
```

### add remote ssh key for git push/pull

```sh
ftpsh mkdir -p ./.ssh
ftpsh ssh-keygen -t rsa -f ./.ssh/id_rsa -N ''
ftpsh "echo 'Deny from all' > ./.ssh/.htaccess"
ftpsh cat ./.ssh/id_rsa.pub
ftpsh "ssh-keyscan github.com 2>/dev/null >> .ssh/known_hosts"
ftpsh "echo 'Host github.com' > .ssh/config; echo '    IdentityFile ~/.ssh/id_rsa' >> .ssh/config"
ftpsh chmod 600 ./.ssh/id_rsa
ftpsh chmod 700 ./.ssh
ftpsh git config core.sshCommand "ssh -i ./.ssh/id_rsa -o IdentitiesOnly=yes"
```
