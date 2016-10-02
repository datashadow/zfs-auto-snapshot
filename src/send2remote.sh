#!/bin/bash
if [ "$#" -ne 2 ]; then
    echo "illegal number of parameters" >&2
    exit 1
fi
#set -x
srcssh=$(expr "$1" : '\(^.*\):') #' Fix mc
[ -z $srcssh ] || srcssh="ssh $srcssh"
srcfs=${1#*:}
dstssh=$(expr "$2" : '\(^.*\):') #' Fix mc
[ -z $dstssh ] || dstssh="ssh $dstssh"
dstfs=${2#*:}
echo 1*$srcssh 2*$dstssh
#exit
get_snaps_src(){
    $srcssh zfs list -rd1 -tsnap -H -oname -S creation $srcfs | sed -e 's/^.*@//'
}
get_snaps_dst(){
    $dstssh zfs list -rd1 -tsnap -H -oname -S creation $dstfs/$srcfs | sed -e 's/^.*@//'
}

for srcfs in $(zfs list -rHt filesystem,volume -o name $srcfs); do
    tosnap=$(get_snaps_src | head -n 1)
    [ -z $tosnap ] && continue
    fromsnap=$(grep -Fx -f <(get_snaps_dst) <(get_snaps_src) | head -n 1)
    [ x$tosnap = x$fromsnap ] && continue
    if [ -z $fromsnap ]; then
        inc=
        tosnap=$(get_snaps_src | tail -n 1)
    else
        inc="-i@$fromsnap"
    fi

    echo "### $srcfs $fromsnap -> $tosnap"
    $srcssh zfs send -p $inc $srcfs@$tosnap | $dstssh zfs recv -vFus $dstfs/$srcfs
    T=$(zfs get type -Ho value $srcfs)
    if [ "$T" = "filesystem" -a -z "$fromsnap" ]; then
        echo $dstssh zfs set canmount=off $dstfs/$srcfs
    fi
done
