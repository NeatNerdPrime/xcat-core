root=1
rootok=1
netroot=xcat
for HDIR in "" "/lib/dracut/hooks"; do
  [ -d "${HDIR}/initqueue-finished" ] || continue
  echo '[ -e $NEWROOT/proc ]' > ${HDIR}/initqueue-finished/xcatroot.sh
done
