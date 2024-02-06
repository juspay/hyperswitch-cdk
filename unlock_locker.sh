pods=( $(kubectl get pods -n hyperswitch -l app=hyperswitch-card-vault | awk '{ print $1 }' | tail -n +2) )
declare -p pods

# port forward to all the pods and store ports in an array
declare -a ports=()
declare -a pids=()
declare -i start=8080
for pod in ${pods[@]}; do
  kubectl port-forward -n hyperswitch $pod 8080:$start &
  pids+=( $! )
  ports+=( $start )
  declare -i start=$((start+1))
done

sleep 10
echo "Enter the keys that are created during the locker master key generation"
echo "Enter key 1: "; read -s; \
  for pod in ${ports[@]}; do \
    curl -X POST -H "Content-Type: application/json" -d '{"key": "'$REPLY'"}' http://localhost:$pod/custodian/key1 -v; \
  done


echo "Enter key 2 "; read -s; \
  for pod in ${ports[@]}; do \
    curl -X POST -H "Content-Type: application/json" -d '{"key": "'$REPLY'"}' http://localhost:$pod/custodian/key2 -v; \
  done

for pod in ${ports[@]}; do
  curl -X POST http://localhost:$pod/custodian/decrypt -v;
done

for pid in ${pids[@]}; do
  kill $pid
done