#!/usr/bin/env bash
RED='\033[1;91m'
YELLOW='\033[1;93m'
WHITE='\033[1;97m'
LBLUE='\033[1;96m'
LGREEN='\033[1;92m'
NOCOLOR='\033[0m'
read -p "Enter node name: " AGORIC_NODENAME
echo 'export AGORIC_NODENAME='$AGORIC_NODENAME >> $HOME/.bashrc
. ~/.bashrc
printf "%b\n\n\n" "${NOCOLOR}${AGORIC_NODENAME}"
install_essentials='curl ufw sudo git pkg-config build-essential libssl-dev nodejs=12.* yarn jq'
if
   printf "%b\n\n\n" "${WHITE} --------------------------------------------------------------------------------"
   printf "%b\n\n\n" "${WHITE} Checking requirements ..."
   sleep 1
   dpkg-query -l 'curl' 'ufw' 'sudo' 'git' 'pkg-config' 'build-essential' 'libssl-dev' 'nodejs' 'yarn' 'jq' > /dev/null 2>&1
  then
   printf "%b\n\n\n" "${WHITE} You have all the required packages for this installation ..."
   printf "%b\n\n\n" "${LGREEN} Continuing ..."
   printf "%b\n\n\n" "${WHITE} --------------------------------------------------------------------------------"
  else
   printf "%b\n\n\n" "${WHITE} Some required packages for this script are not installed"
   printf "%b\n\n\n" "${WHITE} Installing them for you"
   sleep 1
   wget https://golang.org/dl/go1.15.8.linux-amd64.tar.gz && tar -C /usr/local -xzf go1.15.8.linux-amd64.tar.gz
   echo 'export PATH=$PATH:/usr/local/go/bin' >> $HOME/.bash_profile
   echo 'export GOPATH=/usr/local/go' >> $HOME/.bash_profile
   . ~/.bash_profile
   curl -s https://deb.nodesource.com/setup_12.x | sudo bash
   curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
   echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
   printf "%b\n\n\n" "${WHITE} Wait for installing ..."
   apt-get -qq update > /dev/null 2>&1 && apt-get -qq install ${install_essentials} -y > /dev/null 2>&1
   printf "%b\n\n\n" "${WHITE} Now you have all the required packages for this installation ..."
   printf "%b\n\n\n" "${LGREEN} Continuing ... "
   printf "%b\n\n\n" "${WHITE} --------------------------------------------------------------------------------"
fi

printf "%b\n\n\n" "${WHITE} Cloning agoric repo ..."
printf "%b\n\n\n" "${WHITE} --------------------------------------------------------------------------------"
sleep 1
export GIT_BRANCH="@agoric/sdk@2.15.1"
git clone https://github.com/Agoric/agoric-sdk -b $GIT_BRANCH
printf "%b\n\n\n" "${LGREEN} Done!"
printf "%b\n\n\n" "${WHITE} --------------------------------------------------------------------------------"
printf "%b\n\n\n" "${WHITE} Compile Agoric SDK ..."
printf "%b\n\n\n" "${WHITE} --------------------------------------------------------------------------------"
(cd agoric-sdk && npm --force install -g yarn && yarn install && yarn build)
. $HOME/.bashrc && . $HOME/.bash_profile
# . $HOME/.bash_profile
(cd $HOME/agoric-sdk/packages/cosmic-swingset && make)
cd $HOME/agoric-sdk
printf "%b\n\n\n" "${LGREEN} Agoric SDK was installed!"
printf "%b\n\n\n" "${WHITE} --------------------------------------------------------------------------------"
sleep 1
printf "%b\n\n\n" "${WHITE} Set up current chain ..."
curl -s https://testnet.agoric.net/network-config > chain.json
echo 'chainName=`jq -r .chainName < chain.json`' >> $HOME/.bash_profile
. ~/.bash_profile
printf "%b\n\n\n%b" "${LGREEN} Current chain is ${LBLUE}${chainName}"
printf "%b\n\n\n" "${WHITE} --------------------------------------------------------------------------------"
printf "%b\n\n\n%b" "${WHITE} Set up peers ..."
printf "%b\n\n\n" "${WHITE} --------------------------------------------------------------------------------"
ag-chain-cosmos init --chain-id $chainName $AGORIC_NODENAME
curl -s https://testnet.agoric.net/genesis.json > $HOME/.ag-chain-cosmos/config/genesis.json 
ag-chain-cosmos unsafe-reset-all
echo "peers=$(jq '.peers | join(",")' < chain.json)" >> $HOME/.bash_profile
echo "seeds=$(jq '.seeds | join(",")' < chain.json)" >> $HOME/.bash_profile
. ~/.bash_profile
sed -i.bak 's/^log_level/# log_level/' $HOME/.ag-chain-cosmos/config/config.toml && sed -i.bak -e "s/^seeds *=.*/seeds = '$seeds'/; s/^persistent_peers *=.*/persistent_peers = '$peers'/" $HOME/.ag-chain-cosmos/config/config.toml
printf "%b\n\n\n%b" "${LGREEN} Done!"
printf "%b\n\n\n" "${WHITE} --------------------------------------------------------------------------------"
printf "%b\n\n\n%b" "${WHITE} Set up service ..."
printf "%b\n\n\n" "${WHITE} --------------------------------------------------------------------------------"
sudo tee <<EOF >/dev/null /etc/systemd/journald.conf
Storage=persistent
EOF
sudo systemctl restart systemd-journald
sudo tee <<EOF >/dev/null /etc/systemd/system/ag-chain-cosmos.service
[Unit]
Description=Agoric daemon
After=network-online.target
[Service]
User=$USER
ExecStart=/usr/local/go/bin/ag-chain-cosmos start --log_level=warn
Restart=on-failure
RestartSec=3
LimitNOFILE=4096
Environment="OTEL_EXPORTER_PROMETHEUS_PORT="$OTEL_EXPORTER_PROMETHEUS_PORT
[Install]
WantedBy=multi-user.target
EOF
printf "%b\n\n\n%b" "${LGREEN} Done!"
printf "%b\n\n\n" "${WHITE} --------------------------------------------------------------------------------"
printf "%b\n\n\n%b" "${WHITE} Set up metrics ..."
printf "%b\n\n\n" "${WHITE} --------------------------------------------------------------------------------"
echo 'export OTEL_EXPORTER_PROMETHEUS_PORT=9464' >> $HOME/.bash_profile
. ~/.bash_profile
sed -i '/\[telemetry\]/{:a;n;/enabled/s/false/true/;Ta};/\[api\]/{:a;n;/enable/s/false/true/;Ta;}' $HOME/.ag-chain-cosmos/config/app.toml
sed -i "s/prometheus-retention-time = 0/prometheus-retention-time = 60/g" $HOME/.ag-chain-cosmos/config/app.toml
sed -i "s/prometheus = false/prometheus = true/g" $HOME/.ag-chain-cosmos/config/config.toml
printf "%b\n\n\n%b" "${LGREEN} Done!"
printf "%b\n\n\n" "${WHITE} --------------------------------------------------------------------------------"
printf "%b\n\n\n%b" "${WHITE} Run the service ..."
printf "%b\n\n\n" "${WHITE} --------------------------------------------------------------------------------"
sudo systemctl enable ag-chain-cosmos
sudo systemctl daemon-reload
sudo systemctl start ag-chain-cosmos
printf "%b\n" "Node status:${LGREEN}"$(sudo service ag-chain-cosmos status | grep active)
printf "%b\n\n\n%b" "${WHITE}Done!${NOCOLOR}"
