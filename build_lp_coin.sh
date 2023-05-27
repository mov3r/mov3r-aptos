#!/bin/bash

aptos move compile --package-dir ./lp_coin --save-metadata
xxd -plain ./lp_coin/build/lp_coin/package-metadata.bcs | tr -d '\n' >> ./lp_coin/build/lp_coin/package-metadata.bcs.hex
xxd -plain ./lp_coin/build/lp_coin/bytecode_modules/lp_coin.mv | tr -d '\n' >> ./lp_coin/build/lp_coin/lp_coin.hex




