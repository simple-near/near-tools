#!/bin/bash

source ~/.profile
#network=$NEAR_NETWORK
network="mainnet"
nodeType="Primary"
msg="msg"
USER=$(whoami)

echo "checking if neard is running..."
if pgrep -x "neard" >/dev/null
then
    echo "neard is running.";
else
    msg="Near isn't running before the update check! Will checkout, build and deploy the latest version..."
    echo "$msg";
    /home/$USER/near-tools/sendmsg_tgbot.sh "WARNING" "$msg" >> /home/$USER/near-tools/sendmsg.log 2>&1 &
fi

echo checking versions...
version=$(curl -s https://rpc.$network.near.org/status | jq .version.version)
echo "MAINNET version = $version"
localVersion=$(curl -s http://127.0.0.1:3030/status | jq .version.version)
echo "local version = $localVersion"
strippedversion=$(echo "$version" | awk -F "\"" '{print $2}' | awk -F "-" '{print $1}')
#check node version diff
diff <(curl -s https://rpc.$network.near.org/status | jq .version.version) <(curl -s http://127.0.0.1:3030/status | jq .version.version)

#start update if local version is different
if [ $? -ne 0 ]; then
    msg="Starting to update $nodeType node version=$localVersion on $network with version=$strippedversion ..."
	echo "$msg";
	/home/$USER/near-tools/sendmsg_tgbot.sh "ATTENTION" "$msg" >> /home/$USER/near-tools/sendmsg.log 2>&1 &
    [ -d /home/$USER/nearcore.new ] && sudo rm -rf /home/$USER/nearcore.new
    mkdir /home/$USER/nearcore.new
    sudo apt-get update
    sudo apt-get --assume-yes upgrade
    sudo apt-get --assume-yes dist-upgrade
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source ~/.profile
    rustup component add clippy-preview
    rustup default nightly
    [ -d /home/$USER/nearcore.new ] && sudo rm -rf /home/$USER/nearcore.new
    mkdir /home/$USER/nearcore.new
    git clone --branch $strippedversion https://github.com/nearprotocol/nearcore.git /home/$USER/nearcore.new
    cd /home/$USER/nearcore.new
    make release

    #if make was succesfull, test a new node
    if [ $? -eq 0 ]; then
        msg="New build for $nodeType node was successfull, starting test nodes..."
		echo "$msg"
		/home/$USER/near-tools/sendmsg_tgbot.sh "INFO" "$msg" >> /home/$USER/near-tools/sendmsg.log 2>&1 &

        #Remove testing data
        rm -rf /home/$USER/near-tools/localnet/localnet-node0/data
        rm -rf /home/$USER/near-tools/localnet/localnet-node1/data
        rm -rf /home/$USER/near-tools/localnet/localnet-node2/data
        rm -rf /home/$USER/near-tools/localnet/localnet-node3/data

        msg="Test is succesfull, stopping neard and deploying a new $nodeType node on $network version=$strippedversion"
		echo $msg
        /home/$USER/near-tools/sendmsg_tgbot.sh "INFO" "$msg" >> /home/$USER/near-tools/sendmsg.log 2>&1 &

        # =============================
        # DOING NOTHING HERE AS A TEST!
        # =============================
		
        # checking if we started neard
        if pgrep -x "neard" >/dev/null
        then
		    localVersion=$(curl -s http://127.0.0.1:3030/status | jq .version.version)
            msg="Validator with version=$localVersion is up and running as a $nodeType node on $network."
            echo "$msg"
            /home/$USER/near-tools/sendmsg_tgbot.sh "SUCCESS" "$msg" >> /home/$USER/near-tools/sendmsg.log 2>&1 &
        else
            msg="neard is not running on $nodeType node!"
            echo "$msg"
            /home/$USER/near-tools/sendmsg_tgbot.sh "FATAL" "$msg" >> /home/$USER/near-tools/sendmsg.log 2>&1 &
            exit 1
        fi
        echo "All done!"
    else
        msg="Couldn't build neard for a new $nodeType node on $network version=$strippedversion"
        echo "$msg"
        /home/$USER/near-tools/sendmsg_tgbot.sh "ERROR" "$msg" >> /home/$USER/near-tools/sendmsg.log 2>&1 &
    fi
else
    echo "$(date +'%Y-%m-%d %T') No update for the running $nodeType node with version=$strippedversion"
fi
