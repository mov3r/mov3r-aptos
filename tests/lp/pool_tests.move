#[test_only]
module mover::pool_tests {
    use aptos_framework::account;
    use std::signer;
    use mover::liquidity_pool;
    use test_coin_admin::test_coins::{Self, LzUSDC, LzUSDT};
    use aptos_framework::coin;
    use mover::liquidity_pool::LPCoin;

    #[test(
        lp_provider=@lp_provider,
        test_coin_admin=@test_coin_admin,
    )]
    public fun test_mint_and_deposit(
        lp_provider: signer,
        test_coin_admin: signer,

    ) {
        account::create_account_for_test(signer::address_of(&test_coin_admin));
        account::create_account_for_test(signer::address_of(&lp_provider));

        test_coins::register_coins(&test_coin_admin);
        test_coins::mint_and_deposit<LzUSDC>(&lp_provider,100);
        assert!(coin::balance<LzUSDC>(@lp_provider) == 100, 1);
    }


    #[test_only]
    public fun initialize_test_pools(
        mover_admin: &signer,
        test_coin_admin: &signer,
    ) {
        account::create_account_for_test(signer::address_of(mover_admin));
        account::create_account_for_test(signer::address_of(test_coin_admin));

        test_coins::register_coins(test_coin_admin);

        liquidity_pool::register<LzUSDC>(mover_admin);
        liquidity_pool::register<LzUSDT>(mover_admin);
    }

    #[test_only]
    public fun initialize_test_pools_with_liquidity(
        mover_admin: &signer,
        test_coin_admin: &signer,
        lp_provider: &signer,
        usdc_amount: u64,
        usdt_amount: u64,
    ) {
        let lp_provider_address = signer::address_of(lp_provider);
        account::create_account_for_test(lp_provider_address);
        initialize_test_pools(mover_admin, test_coin_admin);

        let lzusdc_coins = test_coins::mint<LzUSDC>(test_coin_admin, usdc_amount);
        let lzusdt_coins = test_coins::mint<LzUSDT>(test_coin_admin, usdt_amount);
        coin::register<LzUSDC>(lp_provider);
        coin::register<LzUSDT>(lp_provider);
        coin::deposit(lp_provider_address, lzusdc_coins);
        coin::deposit(lp_provider_address, lzusdt_coins);
        liquidity_pool::provide_liquidity<LzUSDC>(lp_provider, usdc_amount);
        liquidity_pool::provide_liquidity<LzUSDT>(lp_provider, usdt_amount);

        let n_val = liquidity_pool::reserves<LzUSDT>();
        assert!(n_val == usdt_amount, 1);

        let n_val = liquidity_pool::reserves<LzUSDC>();
        assert!(n_val == usdc_amount, 1);

        assert!(coin::balance<LPCoin<LzUSDC>>(lp_provider_address) == usdc_amount, 1);
        assert!(coin::balance<LPCoin<LzUSDT>>(lp_provider_address) == usdt_amount, 1);
        assert!(coin::balance<LzUSDC>(lp_provider_address) == 0, 1);
        assert!(coin::balance<LzUSDT>(lp_provider_address) == 0, 1);
    }

    #[test(
        mover_admin=@mover,
        test_coin_admin=@test_coin_admin,
        lp_provider=@lp_provider,
    )]
    public fun test_provide_and_withdraw_liquidity(
        mover_admin: signer,
        test_coin_admin: signer,
        lp_provider: signer,
    ) {
        let lp_provider_address = signer::address_of(&lp_provider);
        let usdc_amount = 100;
        let usdt_amount = 200;

        initialize_test_pools_with_liquidity(
            &mover_admin,
            &test_coin_admin,
            &lp_provider,
            usdc_amount,
            usdt_amount,
        );

        liquidity_pool::withdraw_liquidity<LzUSDC>(&lp_provider, usdc_amount);
        liquidity_pool::withdraw_liquidity<LzUSDT>(&lp_provider, usdt_amount);
        assert!(coin::balance<LPCoin<LzUSDC>>(lp_provider_address) == 0, 1);
        assert!(coin::balance<LPCoin<LzUSDT>>(lp_provider_address) == 0, 1);
        assert!(coin::balance<LzUSDC>(lp_provider_address) == usdc_amount, 1);
        assert!(coin::balance<LzUSDT>(lp_provider_address) == usdt_amount, 1);
    }

    #[test(
        mover_admin=@mover,
        test_coin_admin=@test_coin_admin,
        lp_provider=@lp_provider,
        user=@bridge_user,
    )]
    public fun test_lock_release(
        mover_admin: signer,
        test_coin_admin: signer,
        lp_provider: signer,
        user: signer,
    ) {
        account::create_account_for_test(signer::address_of(&user));

        let usdc_amount: u64 = 1000;
        let usdt_amount: u64 = 2000;
        initialize_test_pools_with_liquidity(
            &mover_admin,
            &test_coin_admin,
            &lp_provider,
            usdc_amount,
            usdt_amount,
        );

        let native_coin = liquidity_pool::release<LzUSDC>(&mover_admin, 10);
        assert!(coin::value(&native_coin) == 10, 1);
        let native_val = liquidity_pool::reserves<LzUSDC>();
        assert!(native_val == usdc_amount - 10, 2);

        liquidity_pool::lock<LzUSDC>(native_coin);
        let native_val = liquidity_pool::reserves<LzUSDC>();
        assert!(native_val == usdc_amount, 3);
    }

    #[test(
        mover_admin=@mover,
        test_coin_admin=@test_coin_admin,
        lp_provider=@lp_provider,
        user=@bridge_user,
    )]
    public fun test_emergency_withdrawal(
        mover_admin: signer,
        test_coin_admin: signer,
        lp_provider: signer,
        user: signer,
    ) {
        account::create_account_for_test(signer::address_of(&user));
        let usdc_amount: u64 = 1000;
        let usdt_amount: u64 = 2000;
        initialize_test_pools_with_liquidity(
            &mover_admin,
            &test_coin_admin,
            &lp_provider,
            usdc_amount,
            usdt_amount,
        );
        coin::register<LzUSDC>(&mover_admin);
        coin::register<LzUSDT>(&mover_admin);

        assert!(coin::balance<LzUSDC>(signer::address_of(&mover_admin)) == 0, 1);
        liquidity_pool::emergency_withdraw<LzUSDC>(&mover_admin, 1000);
        assert!(coin::balance<LzUSDC>(signer::address_of(&mover_admin)) == 1000, 1);

        assert!(coin::balance<LzUSDT>(signer::address_of(&mover_admin)) == 0, 1);
        liquidity_pool::emergency_withdraw<LzUSDT>(&mover_admin, 500);
        assert!(coin::balance<LzUSDT>(signer::address_of(&mover_admin)) == 500, 1);
        liquidity_pool::emergency_withdraw<LzUSDT>(&mover_admin, 500);
        assert!(coin::balance<LzUSDT>(signer::address_of(&mover_admin)) == 1000, 1);
    }

}
