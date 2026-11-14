#################################################
# sf-common.sh
#
# SourceForge access shared by the build scripts: .env loading, the release
# paths and the ssh options that work with the restricted
# web.sourceforge.net account. Sourced, never run on its own.
#################################################

# Directory of this script (the repo root). Named SF_* so this can be sourced
# by scripts that already use BASED for something else.
SF_WEB="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

# .env (gitignored) - anything already exported wins, same rule as vps-build.sh
if [ -f "$SF_WEB/.env" ]; then
	while IFS='=' read -r _k _v; do
		case "$_k" in ''|\#*) continue ;; esac
		_v=${_v%\"}; _v=${_v#\"}
		eval "_cur=\${$_k+SET}"
		[ "$_cur" = SET ] || eval "export $_k=\$_v"
	done < "$SF_WEB/.env"
	unset _k _v _cur
fi

SF_USER="${SF_USER:-}"
SF_HOST="${SF_HOST:-web.sourceforge.net}"
SF_FRS="${SF_FRS:-/home/frs/project/litegapps}"
SF_SSH_KEY="${SF_SSH_KEY:-}"

SSH_OPTS="-o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30"
[ -n "$SF_SSH_KEY" ] && SSH_OPTS="$SSH_OPTS -i $SF_SSH_KEY -o IdentitiesOnly=yes"

print(){ echo "$1"; }

need_sf(){
	if [ -z "$SF_USER" ]; then
		print "[ERROR] SF_USER is not set - put it in .env"
		exit 1
	fi
	for W in rsync ssh; do
		command -v "$W" >/dev/null || { print "[ERROR] executable <$W> not found"; exit 1; }
	done
}

