#!/bin/bash
if [ "$#" -ne 2 ]; then
    echo "illegal number of parameters" >&2
    exit 1
fi
#set -x
srcssh=$(expr "$1" : '\(^.*\):') #' Fix mc
[ -z $srcssh ] || srcssh="ssh $srcssh"
srcfs0=${1#*:}
dstssh=$(expr "$2" : '\(^.*\):') #' Fix mc
[ -z $dstssh ] || dstssh="ssh $dstssh"
dstfs=${2#*:}

#filter frequent & daily
ffd=" -e /frequent\|hourly/d"

get_snaps_src(){
    $srcssh zfs list -rd1 -tsnap -H -oname -S creation $srcfs | sed -e 's/^.*@//' $ffd
}

get_origin_src(){
    $srcssh zfs get origin -Ho value $srcfs | sed -e '/^-/d'
}

get_snaps_dst(){
    $dstssh zfs list -rd1 -tsnap -H -oname -S creation $dstfs/$srcfs | sed -e 's/^.*@//' 2>&1
}

for srcfs in $($srcssh zfs list -rHt filesystem,volume -o name,bla.ssc:auto-send $srcfs0 | awk ' $2 != "false" {print $1}'); do
    tosnap=$(get_snaps_src | head -n 1)
    [ -z $tosnap ] && continue
    fromsnap=$(grep -Fx -f <(get_snaps_dst) <(get_snaps_src) | head -n 1)
    if [ x$tosnap = x$fromsnap ]; then
        echo "### $srcfs up to date"
        continue
    fi

    if [ -z $fromsnap ]; then
        fromsnap=$(get_origin_src)
    else
        fromsnap=@$fromsnap
    fi

    if [ -z $fromsnap ]; then
        inc=
        tosnap=$(get_snaps_src | tail -n 1)
    else
        inc="-I$fromsnap"
    fi

    echo "### $srcfs $fromsnap -> $tosnap"
    $srcssh zfs send -p $inc $srcfs@$tosnap | $dstssh zfs recv -vFu $dstfs/$srcfs
    T=$($srcssh zfs get type -Ho value $srcfs)
    if [ "$T" = "filesystem" -a -z "$fromsnap" ]; then
        echo $dstssh zfs set canmount=off $dstfs/$srcfs
    fi
done
echo !!!!!!! delete deleted $srcfs
deleted=$(diff --old-group-format='' --unchanged-group-format='' \
<($srcssh zfs list -rHt filesystem,volume -o name,bla.ssc:auto-send $srcfs0 | awk ' $2 != "false" {print $1}') \
<($dstssh zfs list -rHt filesystem,volume -o name $dstfs/$srcfs0 | sed s,$dstfs/,,))

for D in $deleted; do
    echo destroy $dstfs/$D
    $dstssh zfs destroy -r $dstfs/$D
done
