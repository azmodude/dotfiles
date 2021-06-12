#!/bin/bash
# Sign in to 1Password and save our session key with minimal permissions into the
# kernel keyring user session

KEY_DESCRIPTION="1password-op-session"
PASSWORD_REALM="my"
SESSION_TIMEOUT=1800 # 30 minutes is the default for now

existing_key=$(keyctl show @u | grep "${KEY_DESCRIPTION}" | sed -r 's/^[ ]//' | cut -d " " -f 1)

if [[ -z "${existing_key}" ]] ; then
    session_key=$(op signin "${PASSWORD_REALM}" --raw)
    kernel_key=$(keyctl add user "${KEY_DESCRIPTION}" "${session_key}" @u)
    keyctl timeout "${kernel_key}" "${SESSION_TIMEOUT}"
    keyctl setperm "${kernel_key}" 0x000B0000 # search, read, view
    keyctl pipe "${kernel_key}"
else
    keyctl pipe "${existing_key}"
fi


