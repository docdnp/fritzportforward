#!/usr/bin/env bash
set -e

INST_ROOT=/usr/local
[ "$UID" -gt 0 ] && INST_ROOT=~/.local
SHAREDIR=$INST_ROOT/share/fritztools
BINDIR=$INST_ROOT/bin
FRITZBOX_CONFIG=$SHAREDIR/connection

usage () {
cat <<EOF
Usage: $0 [options]

    -h|--help       show this help
    -n|--nocred     don't ask for credentials during install
    -t|--notest     don't check the installation
    -k|--keep-conf  keep configuration of old installation if applicable
                    (implies --nocred)

EOF
USAGE=true
exit $1
}

check () {
    [ -x "$(command -v $1)" ] && return 0
    echo "Error: Couldn't find command '$1' in PATH."
    usage 1
}

# Setup installation
cleanup () {
    [ -x "$BINDIR/fritztools" ] && return
    $USAGE || echo "WARNING! Installation incomplete! Removing temporary data."
    rm -rf $SHAREDIR $BINDIR/fritz*
    rm -f fritztools
}
trap cleanup TERM EXIT

main () {
    check python3
    check pipenv
    remove_old_installation 
    mkdir -p $SHAREDIR $BINDIR
    create_config
    create_venv
    install_tools
    test_install
    mv ./fritztools $BINDIR
    echo "Installation successful."
}

# Check and remove old installation
remove_old_installation () {
    [ -x $BINDIR/fritztools ] && {
         grep ^FRITZ $FRITZBOX_CONFIG >&/dev/null && {
            [ $KEEP_CONFIG == y ] \
                || read -p "Found a previous installation. Keep the old configuration (y[=default]/n)? " KEEP_CONFIG
            KEEP_CONFIG=${KEEP_CONFIG:-y}
            [ "$KEEP_CONFIG" == y ] && {
                cp $FRITZBOX_CONFIG connection
            }
        }
        $BINDIR/fritztools --uninstall -y
        return 0
    } 
    KEEP_CONFIG=n
    NOCRED=false
    return 0
}

# Ask for credentials and install them
create_config () {
    mk_fritztools fritztools
    touch $FRITZBOX_CONFIG
    [ "$KEEP_CONFIG" == y ] \
        && mv connection $FRITZBOX_CONFIG \
        && source $FRITZBOX_CONFIG \
        && return
    $NOCRED || ./fritztools --config
    source $FRITZBOX_CONFIG
    return 0
}

# Create and move virtual environment
create_venv () {
    PIPENV_QUIET=1 WORKON_HOME=$SHAREDIR pipenv --python 3 sync
    VENV=$(PIPENV_QUIET=1 WORKON_HOME=$SHAREDIR pipenv --python 3 run bash -c 'eval "echo $VIRTUAL_ENV"')
    cp fritzportforward $VENV/bin 
    for tool in $VENV/bin/fritz* ; do sed -i"" -e "s|#!.*|#!$SHAREDIR/virtualenv/bin/python|" $tool ; done
    mv $VENV $SHAREDIR/virtualenv
    VENV=$SHAREDIR/virtualenv
    return 0
}

# Install tool wrapper(s)
install_tools () {
TOOLS=( $(find $VENV/bin -name 'fritz*' -exec basename {} \;) )
PYPATH=$(ls -d1 $VENV/lib/python*)
for tool in ${TOOLS[*]} ; do
cat <<EOF > $BINDIR/$tool
#!/usr/bin/env bash
source "$FRITZBOX_CONFIG"
PYTHONPATH=$PYPATH/site-packages $VENV/bin/$tool \$FRITZBOX_ADDRESS \$FRITZBOX_USER \$FRITZBOX_PASSWORD "\$@"
EOF
chmod +x $BINDIR/$tool
done
mk_fritztools fritztools
return 0
}

# Test installtion
test_install () {
    $NOTEST && return
    echo "Testing installation..."
    [ -z "$FRITZBOX_ADDRESS"         ] && read -p "What's your FritzBox address ?   " FRITZBOX_ADDRESS 2>&1
    [ -z "$FRITZBOX_USER"            ] && read -p "What's your FritzBox user name ? " FRITZBOX_USER 2>&1
    [ -z "$FRITZBOX_PASSWORD"        ] && read -p "What's your FritzBox password?   " FRITZBOX_PASSWORD 2>&1
    ! [[ "$FRITZBOX_ADDRESS"  =~ ^- ]] && FRITZBOX_ADDRESS="-i $FRITZBOX_ADDRESS"
    ! [[ "$FRITZBOX_USER"     =~ ^- ]] && 
       [ "$FRITZBOX_USER"    != ' '  ] && 
       [ "$FRITZBOX_USER"    != ''   ] && FRITZBOX_USER="-u $FRITZBOX_USER"
    ! [[ "$FRITZBOX_PASSWORD" =~ ^- ]] && FRITZBOX_PASSWORD="-p $FRITZBOX_PASSWORD"
    fritzportforward $FRITZBOX_ADDRESS $FRITZBOX_USER $FRITZBOX_PASSWORD -l >&/dev/null || {
        echo "Couldn't query FritzBox data. Credentials and address ok? Installation aborted."
        exit 1
    }
}

# Create fritztools uninstaller and bash-completer
mk_fritztools () {
cat <<EOF > $1
#!/usr/bin/env bash
set -e
if [ "\$1" == "--complete" ] ; then
    shift
    ARG=\${COMP_ARG}
    [ -z "\$ARG" ] && exit
    \$1 -h | perl -ne '
        \$_=~/^\s+(-[a-z\d])[\s,]/i && print "\$1 \n";                    # find short options at beginning of line
        \$_=~/^\s+(--[a-z-\d]+)[\s,]/i && print "\$1 \n";                 # find long options at beginning of line
        \$_=~/^\s+-[a-z\d](?:.*?),\s+(--[a-z\-\d]+)/i && print "\$1 \n"   # find long options after short options
        ' | grep ^\$ARG 
elif [ "\$1" == "--bash-completion" ] ; then
cat <<EOT
_fritz_completion()
{
    local ARG="\\\${COMP_WORDS[\\\$COMP_CWORD]}"
    COMPREPLY=( \\\$( COMP_ARG=\\\$ARG fritztools --complete \\\$1 2>/dev/null ) )
}
complete -o default -F _fritz_completion ${TOOLS[*]} fritztools
EOT
elif  [ "\$1" == "--uninstall" ] ; then
    shift
    set -e
    echo -e "Will remove:\n  $SHAREDIR"
    ls -1 $BINDIR/fritz* | sed 's|^$BINDIR|  $BINDIR|' 
    ANS=y
    [ "\$1" == -y ] || ( echo -n "Are you sure, you want to uninstall all fritztools? [y=default|n] " ; read ANS ; )
    if [ "\$ANS" != n ] ; then
        rm -rf $SHAREDIR $BINDIR/fritz*
        echo "Uninstalled fritztools"
    fi
    exit
elif [ "\$1" == "--config" ] ; then
storeconf () {
[ "\$FRITZBOX_USER" == none ] && FRITZBOX_USER=" " || FRITZBOX_USER="-u \$FRITZBOX_USER"
echo Storing FritzBox configuration...
cat <<EOOF > \$1
FRITZBOX_ADDRESS="-i \$FRITZBOX_ADDRESS"
FRITZBOX_USER="\$FRITZBOX_USER"
FRITZBOX_PASSWORD="-p \$FRITZBOX_PASSWORD"
EOOF
chmod 600 \$1
}

read -p "Do you want to configure the FritzBox credentials (y[=default]/n) " CONFIG
CONFIG=\${CONFIG:-y}
[ "\$CONFIG" == y ] && {
    read -p "What's your FritzBox address/name (default: 192.168.178.1)? " FRITZBOX_ADDRESS
    read -p "What's your FritzBox user name (default: none)?             " FRITZBOX_USER
    read -p "What's your FritzBox password?                              " FRITZBOX_PASSWORD
    FRITZBOX_ADDRESS=\${FRITZBOX_ADDRESS:-192.168.178.1}
    FRITZBOX_USER=\${FRITZBOX_USER:-none}
    FRITZBOX_PASSWORD=\${FRITZBOX_PASSWORD:-}
    ping -c 1 \$FRITZBOX_ADDRESS >&/dev/null || {
        echo Cannot ping FritzBox under \$FRITZBOX_ADDRESS... Cancelling installation.
        exit 1
    }
    storeconf $FRITZBOX_CONFIG
}
else
cat <<EOT
Usage: fritztools [Options]
   --uninstall          Uninstall the fritztools
   -y                   Answer with 'yes' to uninstall
   --config             Setup configuration for connecting to FritzBox
   --bash-completion    Provides functions for bash completion. 
                        Do: eval "\\\$(fritztools --bash-completion)"
EOT
fi
EOF
chmod +x $1
}

KEEP_CONFIG=false
NOCRED=false
NOTEST=false
while [ $# -gt 0 ] ; do
    case "$1" in 
        -k|--keep-conf) KEEP_CONFIG=y ; NOCRED=true ; shift ;;
        -n|--nocred)    NOCRED=true ; shift ;;
        -t|--notest)    NOTEST=true ; shift ;;
        -h|--help)      usage ;;
        *) echo "Error: Unknown option: $1" ; usage 1 ;; 
    esac
done 

main "$@"
