# shellcheck shell=bash
_pc_hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_paperclip_pkg_root="$(cd "${_pc_hook_dir}/.." && pwd)"

paperclip_published_host_port() {
    local mf p
    mf="${_paperclip_pkg_root}/umbrel-app.yml"
    if [[ -f "${mf}" ]]; then
        p="$(grep -E '^[[:space:]]*port:' "${mf}" | head -1 | tr -cd '0-9')"
        if [[ -n "${p}" ]]; then
            echo "${p}"
            return
        fi
    fi
    echo "23140"
}
