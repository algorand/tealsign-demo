#!/usr/bin/env bash

set -e
set -o pipefail

GCMD="goal -d $1"

display_usage() {
	echo "Usage: $0 [data-dir]"
}

if [ $# -lt 1 ]
then
	display_usage
	exit 1
fi

set -x

# Multisig group of 4 accounts
mkdir -p keys
export MSIGACCOUNT_1_4=$(algokey generate -f keys/1_4 | tail -1 | awk '{ print $3 }')
export MSIGACCOUNT_2_4=$(algokey generate -f keys/2_4 | tail -1 | awk '{ print $3 }')
export MSIGACCOUNT_3_4=$(algokey generate -f keys/3_4 | tail -1 | awk '{ print $3 }')
export MSIGACCOUNT_4_4=$(algokey generate -f keys/4_4 | tail -1 | awk '{ print $3 }')

# Multisig group of 3 accounts
export MSIGACCOUNT_1_3=$(algokey generate -f keys/1_3 | tail -1 | awk '{ print $3 }')
export MSIGACCOUNT_2_3=$(algokey generate -f keys/2_3 | tail -1 | awk '{ print $3 }')
export MSIGACCOUNT_3_3=$(algokey generate -f keys/3_3 | tail -1 | awk '{ print $3 }')

# Generate address for recipient
export RECIPIENT=$(algokey generate | tail -1 | awk '{ print $3 }')

set +x

# Copy contract and substitute values

cp contract.tmpl.teal contract.teal

sed -i -e "s/TMPL_KEY_1_4/${MSIGACCOUNT_1_4}/g" contract.teal
sed -i -e "s/TMPL_KEY_2_4/${MSIGACCOUNT_2_4}/g" contract.teal
sed -i -e "s/TMPL_KEY_3_4/${MSIGACCOUNT_3_4}/g" contract.teal
sed -i -e "s/TMPL_KEY_4_4/${MSIGACCOUNT_4_4}/g" contract.teal

sed -i -e "s/TMPL_KEY_1_3/${MSIGACCOUNT_1_3}/g" contract.teal
sed -i -e "s/TMPL_KEY_2_3/${MSIGACCOUNT_2_3}/g" contract.teal
sed -i -e "s/TMPL_KEY_3_3/${MSIGACCOUNT_3_3}/g" contract.teal

# Compile contract

# set -x
# TODO: Fund this address so sending really works
# export CONTRACT=$(goal clerk compile contract.teal -o contract.tealc | awk '{ print $2 }')
# set +x

# set -x

# Show that sending fails without multisig args
goal clerk send -F contract.teal -t $RECIPIENT -a 1234 -d $1 || true

# Now we'll show that sending fails with only one signature from each set

# First, write the tx out to a file for tealsign-ing
rm -f tosign.tx.rej
goal clerk send -F contract.teal -t $RECIPIENT -o tosign.tx -a 1234 -d $1

# Fill placeholder sigs for 4 multisig (all sigs from key 1/4)
goal clerk tealsign --sign-txid --keyfile keys/1_4 --lsig-txn tosign.tx --set-lsig-arg 0
goal clerk tealsign --sign-txid --keyfile keys/1_4 --lsig-txn tosign.tx --set-lsig-arg 1
goal clerk tealsign --sign-txid --keyfile keys/1_4 --lsig-txn tosign.tx --set-lsig-arg 2
goal clerk tealsign --sign-txid --keyfile keys/1_4 --lsig-txn tosign.tx --set-lsig-arg 3

# Fill placeholder  --sign-txidsigs for 3 multisig (all sigs from key 1/3)
goal clerk tealsign --sign-txid --keyfile keys/1_3 --lsig-txn tosign.tx --set-lsig-arg 4
goal clerk tealsign --sign-txid --keyfile keys/1_3 --lsig-txn tosign.tx --set-lsig-arg 5
goal clerk tealsign --sign-txid --keyfile keys/1_3 --lsig-txn tosign.tx --set-lsig-arg 6

# Try broadcasting (not enough sigs)
goal clerk rawsend -f tosign.tx -d $1 || true

# Now, give enough signatures

# Fill placeholder sigs for 4 multisig (all sigs from key 1/4)
goal clerk tealsign --sign-txid --keyfile keys/1_4 --lsig-txn tosign.tx --set-lsig-arg 0
goal clerk tealsign --sign-txid --keyfile keys/2_4 --lsig-txn tosign.tx --set-lsig-arg 1
goal clerk tealsign --sign-txid --keyfile keys/3_4 --lsig-txn tosign.tx --set-lsig-arg 2
goal clerk tealsign --sign-txid --keyfile keys/1_4 --lsig-txn tosign.tx --set-lsig-arg 3

# Fill placeholder  --sign-txidsigs for 3 multisig (all sigs from key 1/3)
goal clerk tealsign --sign-txid --keyfile keys/1_3 --lsig-txn tosign.tx --set-lsig-arg 4
goal clerk tealsign --sign-txid --keyfile keys/2_3 --lsig-txn tosign.tx --set-lsig-arg 5
goal clerk tealsign --sign-txid --keyfile keys/1_3 --lsig-txn tosign.tx --set-lsig-arg 6

# Should succeed (unless insufficient balance)
rm -f tosign.tx.rej
goal clerk rawsend -f tosign.tx -d $1 || true

# Clean up
rm -r contract.teal tosign.tx tosign.tx.rej keys
