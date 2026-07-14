#!/bin/bash
# setup.sh — runs after container creation / rebuild.
#
# This is provisioning glue, so it is intentionally BEST-EFFORT and does NOT use
# `set -e`: a single transient failure (a slow puppet master, a flaky curl) must
# never abort the rest or leave the box half-configured. Every step is
# independent and guarded, the critical network-free steps run FIRST, and the
# script always exits 0 so a rebuild is never marked failed for an optional step.

log() { echo "[setup] $*"; }

WT="/home/mbetamony/sourcegit/literatum-worktrees/lit-2410/atypon"   # active worktree (== workspaceFolder)
SHARED="/home/mbetamony/sourcegit/.devcontainer"                     # shared devcontainer scripts

# ==========================================
# 0. IDENTITY (belt-and-suspenders)
# ==========================================
# Also baked into the image (Dockerfile ENV) and devcontainer.json env. Exported
# here too so the provisioning shell and the puppet run have it. Without $USER,
# env.py/setprod die with KeyError: 'USER'.
export USER="${USER:-mbetamony}"
export LOGNAME="${LOGNAME:-mbetamony}"

# machine_type as an ENVIRONMENT fact — this is the one that actually fixes the
# 500. The installer (install_debian_agent.sh) runs `rm -fr /etc/puppetlabs/`,
# which deletes any FILE fact before the agent run it triggers; a FACTER_* env var
# can't be purged. It's also set in the image (Dockerfile ENV) and preserved
# across sudo via /etc/sudoers.d/facter_machine_type. Exported here too so a
# standalone run of this script is covered.
export FACTER_machine_type="workstation"

# ==========================================
# 1. CRITICAL, NETWORK-FREE STEPS (must always succeed) — run first
# ==========================================
# 1a. machine_type file fact — secondary/defence-in-depth. NOTE: the installer's
#     `rm -fr /etc/puppetlabs/` wipes this before its own agent run, so the env
#     fact above is what carries the value through that run; this file only helps
#     later, manual `puppet agent -t` invocations.
sudo mkdir -p /etc/puppetlabs/facter/facts.d
echo "machine_type=workstation" | sudo tee /etc/puppetlabs/facter/facts.d/machine_type.txt >/dev/null

# 1b. git safe directories
git config --global --add safe.directory '*' || true

# 1c. SELF-HEAL: remove the self-referential nested worktree dirs that confuse
#     IntelliJ — a doubled $WT/literatum-worktrees/lit-2410/atypon (+ a stray
#     .idea) and an empty $WT/literatum-patch-worktrees. The `case` guard ensures
#     we only ever delete paths INSIDE the worktree, never the real top-level
#     ~/sourcegit/literatum-worktrees.
for junk in "$WT/literatum-worktrees" "$WT/literatum-patch-worktrees"; do
  case "$junk" in
    "$WT/"*)
      if [ -e "$junk" ]; then
        log "removing stray nested dir: $junk"
        rm -rf "$junk" || true
      fi
      ;;
  esac
done

# 1d. midtier conf dir + user aliases
mkdir -p /home/mbetamony/source/HEAD/atypon/product/midtier/conf/ || true
sudo mkdir -p /etc/network/if-up.d || true
if [ -f "$SHARED/.bash_aliases" ]; then
  cp "$SHARED/.bash_aliases" ~/.bash_aliases || true
fi

# ==========================================
# 2. PYTHON ALTERNATIVES
# ==========================================
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1 || true
sudo update-alternatives --install /usr/bin/python python /usr/bin/python2.7 2 || true

# ==========================================
# 3. WORKSTATION CONFIGURATION
# ==========================================
sudo mkdir -p /var/tmp
{
  echo "office-location:jordan"
  echo "isWorkstation:true"
  echo "user-packages:all_atypon"
} | sudo tee /var/tmp/workstationConfig.config >/dev/null

# ==========================================
# 4. REVOKE OLD PUPPET CERTIFICATE (best-effort)
# ==========================================
# Cleans the stale cert for this certname on the master so a rebuild's fresh key
# gets a freshly-signed, matching cert (avoids "certificate does not match its
# private key"). Every curl is guarded so a slow/unreachable cleaner endpoint can
# never abort the rest of provisioning (this is what caused the earlier exit 1).
revokePuppet() {
  local certname; certname="$(hostname).lan"
  log "cleaning old certificate for ${certname} on the puppet master"
  curl -fsSL http://puppet.atypon.com/cleaner/ca_crt.pem            -o /tmp/ca.pem   || { log "cleaner CA unreachable; skipping revoke"; return 0; }
  curl -fsSL http://puppet.atypon.com/cleaner/puppetcleaner_key.pem -o /tmp/key.pem  || { log "cleaner key unreachable; skipping revoke"; return 0; }
  curl -fsSL http://puppet.atypon.com/cleaner/puppetcleaner_crt.pem -o /tmp/cert.pem || { log "cleaner cert unreachable; skipping revoke"; return 0; }
  curl -s -H "Content-Type: application/json" -X PUT -d '{"desired_state":"revoked"}' \
    "https://puppet.atypon.com:8140/puppet-ca/v1/certificate_status/${certname}" \
    --cacert /tmp/ca.pem --cert /tmp/cert.pem --key /tmp/key.pem || true
  curl -s -H "Content-Type: application/json" -X DELETE \
    "https://puppet.atypon.com:8140/puppet-ca/v1/certificate_status/${certname}" \
    --cacert /tmp/ca.pem --cert /tmp/cert.pem --key /tmp/key.pem || true
  rm -f /tmp/ca.pem /tmp/key.pem /tmp/cert.pem || true
  log "certificate cleanup complete"
}
revokePuppet || true

# ==========================================
# 5. INSTALL + RUN THE PUPPET AGENT (best-effort)
# ==========================================
# The agent run can take a long time and may log fileserver timeouts / per-resource
# failures when the master is loaded — those are expected and must not fail setup.
if curl -fsSL http://puppet.atypon.com:8088/puppet-agent/Linux/debian/install_debian_agent.sh -o /tmp/install_agent.sh; then
  ( cd /tmp && sudo bash /tmp/install_agent.sh -C -P -L mbetamony -A 00000 ) || true
else
  log "could not download puppet installer; skipping agent run"
fi

cp "$SHARED/deployconf.xml" ~/deployconf.xml || true

log "setup complete"
exit 0