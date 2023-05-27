#[test_only]
module mover::bridge_tests {

    #[test_only]
    use aptos_framework::aptos_account;
    use mover::bridge;
    use aptos_framework::coin;
    use mover::chains::{Arbitrum, Ethereum};
    use std::string::utf8;
    use test_coin_admin::test_coins;
    use test_coin_admin::test_coins::{Self, LzUSDC, LzUSDT};
    use mover::liquidity_pool;
    use std::signer;
    use std::option;
    use mover::wrapped_coins::{MoverUSDC, MoverUSDT};

    const NATIVE_COIN: u64 = 1;
    const WRAPPED_COIN: u64 = 2;


    #[test_only]
    public fun initialize_tests(
        mover: &signer,
        test_coins_admin: &signer,
    ) {

        aptos_account::create_account(@mover);
        bridge::initialize(mover);
        bridge::add_wrapped_coin<MoverUSDC>(
            mover,
            utf8(b"movUSDC"),
            utf8(b"movUSDC"),
            6);
        bridge::enable_coin<MoverUSDC, Arbitrum>(mover);
        bridge::enable_coin<MoverUSDC, Ethereum>(mover);

        bridge::add_wrapped_coin<MoverUSDT>(
            mover,
            utf8(b"movUSDT"),
            utf8(b"movUSDT"),
            6);
        bridge::enable_coin<MoverUSDT, Arbitrum>(mover);
        bridge::enable_coin<MoverUSDT, Ethereum>(mover);

        assert!(coin::is_coin_initialized<MoverUSDC>(), 1);
        assert!(coin::is_coin_initialized<MoverUSDT>(), 1);

        aptos_account::create_account(@test_coin_admin);
        test_coins::register_coins(test_coins_admin);

        bridge::add_native_coin<LzUSDC>(mover);
        bridge::enable_coin<LzUSDC, Arbitrum>(mover);
        bridge::enable_coin<LzUSDC, Ethereum>(mover);

        bridge::add_native_coin<LzUSDT>(mover);
        bridge::enable_coin<LzUSDT, Arbitrum>(mover);
        bridge::enable_coin<LzUSDT, Ethereum>(mover);

        assert!(liquidity_pool::reserves<LzUSDC>() == 0, 1);
        assert!(liquidity_pool::reserves<LzUSDT>() == 0, 1);
    }

    #[test(mover = @mover, test_coins_admin=@test_coin_admin)]
    public entry fun test_initialize(
        mover: signer,
        test_coins_admin: signer,
    ) {
        initialize_tests(&mover, &test_coins_admin);
    }


    #[test(mover=@mover, user=@user, test_coin_admin=@test_coin_admin)]
//    #[expected_failure(abort_code = 90)]
    public entry fun test_swap_out_limit(
        mover: signer,
        user: signer,
        test_coin_admin: signer,
    ) {
        let user_address = signer::address_of(&user);
        initialize_tests(&mover, &test_coin_admin);

        let amount = 10000000 + 1;
        aptos_account::create_account(user_address);
        coin::register<LzUSDC>(&user);
        let coins = test_coins::mint<LzUSDC>(&test_coin_admin, amount);
        coin::deposit(user_address, coins);
        assert!(coin::balance<LzUSDC>(user_address) == amount, 20);

        bridge::swap_out<LzUSDC, Arbitrum>(
            &user,
            amount,
            utf8(b"deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"),
            1,
        );
    }


    #[test(mover=@mover, user=@user, test_coin_admin=@test_coin_admin)]
    public entry fun test_e2e_native_no_lp(
        mover: signer,
        user: signer,
        test_coin_admin: signer,
    ) {
        let user_address = signer::address_of(&user);
        initialize_tests(&mover, &test_coin_admin);

        aptos_account::create_account(user_address);
        coin::register<LzUSDC>(&user);
        let coins = test_coins::mint<LzUSDC>(&test_coin_admin, 1000);
        coin::deposit(user_address, coins);
        assert!(coin::balance<LzUSDC>(user_address) == 1000, 20);

        bridge::swap_out<LzUSDC, Arbitrum>(
            &user,
            1000,
            utf8(b"deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"),
            1,
        );
        assert!(coin::balance<LzUSDC>(user_address) == 0, 30);
        assert!(liquidity_pool::reserves<LzUSDC>() == 1000, 40);

        bridge::swap_in<LzUSDC,Arbitrum>(
            &mover,
            1000,
            utf8(b"a21808Eeed84C6D7e41291f002ceDcE6FE204Ad5"),
            user_address,
            1,
            0
        );
        assert!(coin::balance<LzUSDC>(user_address) == 1000, 50);
        assert!(liquidity_pool::reserves<LzUSDC>() == 0, 60);

        assert!(*option::borrow<u128>(&coin::supply<LzUSDC>()) == 1000, 70);


    }

    #[test(mover=@mover,
        user=@user,
        test_coin_admin=@test_coin_admin,
    )]
    public entry fun test_e2e_native_lp(
        mover: signer,
        user: signer,
        test_coin_admin: signer,
    ) {
        let user_address = signer::address_of(&user);
        initialize_tests(&mover, &test_coin_admin);

        aptos_account::create_account(user_address);
        coin::register<LzUSDC>(&user);
        let coins = test_coins::mint<LzUSDC>(&test_coin_admin, 1000);
        let lp_coins = liquidity_pool::mint_lp_coins<LzUSDC>(coins);

        assert!(coin::balance<LzUSDC>(user_address) == 0, 20);
        bridge::swap_in<LzUSDC,Arbitrum>(
            &mover,
            400,
            utf8(b"a21808Eeed84C6D7e41291f002ceDcE6FE204Ad5"),
            user_address,
            1,
            0
        );
        assert!(coin::balance<LzUSDC>(user_address) == 400, 50);
        assert!(liquidity_pool::reserves<LzUSDC>() == 600, 60);

        bridge::swap_in<LzUSDC,Ethereum>(
            &mover,
            600,
            utf8(b"a21808Eeed84C6D7e41291f002ceDcE6FE204Ad5"),
            user_address,
            1,
            0
        );
        assert!(coin::balance<LzUSDC>(user_address) == 1000, 50);
        assert!(liquidity_pool::reserves<LzUSDC>() == 0, 60);

        bridge::swap_out<LzUSDC, Arbitrum>(
            &user,
            300,
            utf8(b"deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"),
            1,
        );
        assert!(coin::balance<LzUSDC>(user_address) == 700, 30);
        assert!(liquidity_pool::reserves<LzUSDC>() == 300, 40);

        bridge::swap_out<LzUSDC, Arbitrum>(
            &user,
            700,
            utf8(b"deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"),
            1,
        );
        assert!(coin::balance<LzUSDC>(user_address) == 0, 30);
        assert!(liquidity_pool::reserves<LzUSDC>() == 1000, 40);

        assert!(*option::borrow<u128>(&coin::supply<LzUSDC>()) == 1000, 70);
        let withdrawn_coins = liquidity_pool::burn<LzUSDC>(lp_coins);
        assert!(coin::value(&withdrawn_coins) == 1000, 80);
        assert!(liquidity_pool::reserves<LzUSDC>() == 0, 90);

        test_coins::burn<LzUSDC>(&test_coin_admin, withdrawn_coins);
    }
}