# mov3r-aptos-contracts

### Deploy

In the following instruction, replace 0xDEPLOYMENT_ADDRESS with deployment address.

Publish `lp`, `testcoin` and `bridge` modules :

```shell
aptos move publish --package-dir lp 
aptos move publish --package-dir testcoin
aptos move publish --package-dir .
```

Initialize:

```shell
aptos move run --function-id 0xDEPLOYMENT_ADDRESS::bridge::initialize
aptos move run --function-id 0xDEPLOYMENT_ADDRESS::test_coins::register_coins

aptos move run --function-id 0xDEPLOYMENT_ADDRESS::bridge::add_native_coin --type-args 0xDEPLOYMENT_ADDRESS::test_coins::LzUSDC
aptos move run --function-id 0xDEPLOYMENT_ADDRESS::bridge::add_native_coin --type-args 0xDEPLOYMENT_ADDRESS::test_coins::LzUSDT

aptos move run --function-id 0xDEPLOYMENT_ADDRESS::bridge::enable_coin --type-args 0xDEPLOYMENT_ADDRESS::test_coins::LzUSDC 0xDEPLOYMENT_ADDRESS::chains::Arbitrum
aptos move run --function-id 0xDEPLOYMENT_ADDRESS::bridge::enable_coin --type-args 0xDEPLOYMENT_ADDRESS::test_coins::LzUSDC 0xDEPLOYMENT_ADDRESS::chains::Ethereum

aptos move run --function-id 0xDEPLOYMENT_ADDRESS::bridge::enable_coin --type-args 0xDEPLOYMENT_ADDRESS::test_coins::LzUSDT 0xDEPLOYMENT_ADDRESS::chains::Arbitrum
aptos move run --function-id 0xDEPLOYMENT_ADDRESS::bridge::enable_coin --type-args 0xDEPLOYMENT_ADDRESS::test_coins::LzUSDT 0xDEPLOYMENT_ADDRESS::chains::Ethereum
```

Set fees:

```shell
aptos move run --function-id 0xDEPLOYMENT_ADDRESS::bridge::setFee --type-args 0xDEPLOYMENT_ADDRESS::chains::Arbitrum --args u128:130000
aptos move run --function-id 0xDEPLOYMENT_ADDRESS::bridge::setFee --type-args 0xDEPLOYMENT_ADDRESS::chains::Ethereum --args u128:130000
```

Register and get test coins:

```shell
aptos move run --function-id 0xDEPLOYMENT_ADDRESS::test_coins::mint_and_deposit --type-args 0xDEPLOYMENT_ADDRESS::test_coins::LzUSDC --args u64:100000000000
aptos move run --function-id 0xDEPLOYMENT_ADDRESS::test_coins::mint_and_deposit --type-args 0xDEPLOYMENT_ADDRESS::test_coins::LzUSDT --args u64:100000000000
```

Provide liquidity:

```shell
aptos move run --function-id 0xDEPLOYMENT_ADDRESS::liquidity_pool::provide_liquidity --type-args 0xDEPLOYMENT_ADDRESS::test_coins::LzUSDC  --args u64:1000000000
aptos move run --function-id 0xDEPLOYMENT_ADDRESS::liquidity_pool::provide_liquidity --type-args 0xDEPLOYMENT_ADDRESS::test_coins::LzUSDT  --args u64:1000000000
```

Withdraw liquidity:

```shell
aptos move run --function-id 0xDEPLOYMENT_ADDRESS::liquidity_pool::withdraw_liquidity --type-args 0xDEPLOYMENT_ADDRESS::test_coins::LzUSDC  --args u64:100000
aptos move run --function-id 0xDEPLOYMENT_ADDRESS::liquidity_pool::withdraw_liquidity --type-args 0xDEPLOYMENT_ADDRESS::test_coins::LzUSDT  --args u64:100000
```