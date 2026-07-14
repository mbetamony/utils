# Start from a clean Debian image
FROM debian:bullseye

# Install core utilities, Git, SSH, Python, and Ping
RUN apt-get update && apt-get install -y \
    sudo \
    curl \
    wget \
    git \
    openssh-server \
    python3 \
    python2.7 \
    iputils-ping

# Create your user and give passwordless sudo access
RUN useradd -ms /bin/bash mbetamony && \
    echo "mbetamony ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ==========================================
# IDENTITY — single-user dev container
# ==========================================
# Bake USER/LOGNAME/HOME into the image so EVERY entry path (JetBrains/VS Code
# terminal, `docker exec`, SSH on 2222) has them. A non-login shell does not set
# $USER by itself, and without it:
#   * env.py / setprod crash with `KeyError: 'USER'` -> `lean` fails
#   * the prompt loses its user segment (shows `@literatum@devsc-mbetamony`
#     instead of `mbetamony@literatum@devsc-mbetamony`)
ENV USER=mbetamony \
    LOGNAME=mbetamony \
    HOME=/home/mbetamony \
    FACTER_machine_type=workstation

# ==========================================
# PUPPET machine_type FACT — provided as an ENVIRONMENT fact (not a file)
# ==========================================
# Why not a file: the Atypon installer (install_debian_agent.sh) runs
# `rm -fr /etc/puppetlabs/` before reinstalling the agent, which deletes any file
# fact (e.g. /etc/puppetlabs/facter/facts.d/machine_type.txt) BEFORE the
# `puppet agent -t` it triggers — so a file fact can't fix the 500 here.
#
# Facter also reads facts from `FACTER_<name>` env vars, and nothing purges those.
# FACTER_machine_type (set in ENV above) overrides the broken DMI-based custom
# fact (defaultworkstation.rb crashes on `Facter.value('dmi')['chassis']['type']`
# because containers expose no SMBIOS/DMI), so the node always classifies as a
# workstation and the catalog compiles — no matter what setup.sh does.
#
# The installer and its `puppet agent -t` run under `sudo`, which resets the
# environment, so preserve this one variable across sudo:
RUN echo 'Defaults env_keep += "FACTER_machine_type"' > /etc/sudoers.d/facter_machine_type && \
    chmod 0440 /etc/sudoers.d/facter_machine_type

# Create the SSH privilege separation directory
RUN mkdir -p /run/sshd

# ==========================================
# FIX 1: The Docker Root Lock
# Create the .config folder as the user BEFORE the JetBrains mount happens
# ==========================================
RUN mkdir -p /home/mbetamony/.config && \
    chown mbetamony:mbetamony /home/mbetamony/.config

# ==========================================
# FIX 2: The Mac Git Worktree Hack
# Map the Mac /Users path to the Linux /home path so Git Worktrees don't crash
# ==========================================
RUN mkdir -p /Users && \
    ln -s /home/mbetamony /Users/mbetamony