alias lean="setprod lean -d --source-env cip --cip-family x7481"
alias fullbld="rstrt -bs && rstrt -q && rbld -wcs && rdply -vn && rstrt -wgb"
alias bld="rstrt -bs && rstrt -q && rbld -w && rdply -vn && rstrt -wgb"
alias litlogs="golog && tail -f literatum.log"
alias stderrlogs="'golog && cd .. && tail -f stderr.log"
alias authorea="setprod -d authorea lit-2410 --source-env staging"
alias amps="setprod amps --source-env staging"
alias cdlit="cd ~/sourcegit/literatum-worktrees/lit-2410/atypon"
export PATH="$HOME/.local/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# pnpm
export PNPM_HOME="/home/mbetamony/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

export DOCKER_API_VERSION=1.41
export PATH="$HOME/.cargo/bin:$PATH"
export GO111MODULE=on
export JDK_HOME=$APPSDIR/java21

export JAVA_HOME=/opt/java/java17
export PATH=$JAVA_HOME/bin:$PATH
export JAVA17_HOME=/home/mbetamony/apps64/java17
export PATH="$HOME/.local/bin:$PATH"