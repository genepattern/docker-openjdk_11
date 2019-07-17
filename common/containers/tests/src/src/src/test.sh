echo "setting up sigterm trap"
trap "echo INNER  Booh! == $? received;exit 128" SIGINT SIGTERM EXIT SIGQUIT SIGKILL SIGSTOP SIGHUP


for i in {1..10}
do
  echo "THIS IS THE MODULE SPEAKING...$i"
  sleep 5
  echo "MODULE SAYS here we are $i" >> M_log.txt
  sleep 5 
done

