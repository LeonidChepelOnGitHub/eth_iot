#\!/bin/bash
if [ \! -d /root/.ethereum/geth ]; then
  geth --datadir /root/.ethereum init /root/genesis.json
fi

geth \
  --datadir /root/.ethereum \
  --networkid 1337 \
  --port 30303 \
  --http \
  --http.addr 0.0.0.0 \
  --http.port 8545 \
  --http.api eth,net,web3,personal,miner,clique,admin \
  --http.corsdomain '*' \
  --http.vhosts '*' \
  --ws \
  --ws.addr 0.0.0.0 \
  --ws.port 8546 \
  --ws.api eth,net,web3,personal,miner,clique,admin \
  --ws.origins '*' \
  --mine \
  --miner.etherbase $MINER_ADDRESS \
  --unlock $MINER_ADDRESS \
  --password /root/scripts/password.txt \
  --allow-insecure-unlock \
  --authrpc.addr 0.0.0.0 \
  --authrpc.port 8551 \
  --authrpc.vhosts '*' \
  --verbosity 4