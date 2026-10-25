while sleep 15; do
  C=$(ps -eo pid,cmd | grep "[g]odot-gfx --path" | awk '{print $1}')
  S=$(ps -eo pid,cmd | grep "[t]errain_server.tscn" | wc -l)
  if [ -n "$C" ] && [ "$S" = "0" ]; then sleep 15; S=$(ps -eo pid,cmd | grep "[t]errain_server.tscn" | wc -l); [ "$S" = "0" ] && kill $C; fi
  grep -q MUTDONE /tmp/two_done.txt 2>/dev/null && break
done
