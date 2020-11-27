# set browser environment variable
if [ -e /usr/bin/google-chrome-stable ]; then
    export BROWSER="/usr/bin/google-chrome-stable"
elif [ -e /usr/bin/google-chrome-beta ]; then
    export BROWSER="/usr/bin/google-chrome-beta"
elif [ -e /usr/bin/firefox ]; then
    export BROWSER="/usr/bin/firefox"
fi
