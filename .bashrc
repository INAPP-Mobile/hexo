# .bashrc — node user, loaded by the ttyd web terminal (interactive bash)
# HOME=/app in the container, so this file lives at /app/.bashrc

# Only for interactive shells
case $- in
    *i*) ;;
      *) return;;
esac

# Don't let history writes fail inside /app (root-owned)
export HISTFILE=/tmp/.bash_history

# ---- hexo convenience: put the hexo CLI on PATH ----
export PATH="/app/node_modules/.bin:${PATH}"

# ---- breadcrumb prompt: time + user@host + full path ----
BOLD="\[\e[1m\]"
RESET="\[\e[0m\]"
DIM="\[\e[2m\]"
GREEN="\[\e[32m\]"
CYAN="\[\e[36m\]"
YELLOW="\[\e[33m\]"
MAGENTA="\[\e[35m\]"
PS1="${DIM}\t ${RESET}${GREEN}\u${RESET}@${GREEN}\h${RESET} ${CYAN}\w${RESET}${MAGENTA}\$${RESET} "

# ---- aliases for common hexo tasks ----
alias hg='hexo generate'
alias hd='hexo deploy'
alias hs='hexo server'
alias hn='hexo new'
alias hc='hexo clean'
alias hl='hexo list'
alias hlg='hexo list page'
alias hls='hexo list post'

# ---- echo instructions on terminal open ----
echo
echo -e "${BOLD}Hexo web terminal${RESET} — source: ${CYAN}/app/source${RESET}, public: ${CYAN}/app/public${RESET}"
echo -e "Quick commands:"
echo -e "  ${GREEN}hexo new \"Post title\"${RESET}  create a post"
echo -e "  ${GREEN}hg${RESET} = hexo generate      rebuild the static site"
echo -e "  ${GREEN}hs${RESET} = hexo server        preview server (127.0.0.1:4000)"
echo -e "  ${GREEN}hd${RESET} = hexo deploy        deploy (if configured)"
echo -e "  ${GREEN}hn${RESET} = hexo new, ${GREEN}hc${RESET} = hexo clean, ${GREEN}hl${RESET} = hexo list"
echo -e "Site is regenerated automatically every 60s from admin saves."
echo