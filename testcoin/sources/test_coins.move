module test_coin_admin::test_coins {
    use std::string::utf8;
    use std::signer;

    use aptos_framework::coin::{Self, Coin, MintCapability, BurnCapability};

    struct LzUSDC {}
    struct LzUSDT {}

    struct Capabilities<phantom CoinType> has key {
        mint_cap: MintCapability<CoinType>,
        burn_cap: BurnCapability<CoinType>,
    }

    public entry fun register_coins(admin: &signer) {
        let (lz_usdc_burn_cap,
            lz_usdc_freeze_cap,
            lz_usdc_mint_cap) =
            coin::initialize<LzUSDC>(
                admin,
                utf8(b"lzUSDC"),
                utf8(b"lzUSDC"),
                6,
                true,
            );
        let (lz_usdt_burn_cap,
            lz_usdt_freeze_cap,
            lz_usdt_mint_cap) =
            coin::initialize<LzUSDT>(
                admin,
                utf8(b"lzUSDT"),
                utf8(b"lzUSDT"),
                6,
                true,
            );

        move_to(admin, Capabilities<LzUSDC> {
            mint_cap: lz_usdc_mint_cap,
            burn_cap: lz_usdc_burn_cap,
        });
        move_to(admin, Capabilities<LzUSDT> {
            mint_cap: lz_usdt_mint_cap,
            burn_cap: lz_usdt_burn_cap,
        });

        coin::destroy_freeze_cap(lz_usdc_freeze_cap);
        coin::destroy_freeze_cap(lz_usdt_freeze_cap);
    }

    public entry fun mint_and_deposit<CoinType>(anyuser: &signer, amount: u64) acquires Capabilities {
        let caps = borrow_global<Capabilities<CoinType>>(@test_coin_admin);
        let coins = coin::mint(amount, &caps.mint_cap);
        let user_address = signer::address_of(anyuser);
        if (!coin::is_account_registered<CoinType>(user_address)) {
            coin::register<CoinType>(anyuser);
        };
        coin::deposit(user_address, coins);
    }


    public fun mint<CoinType>(coin_admin: &signer, amount: u64): Coin<CoinType> acquires Capabilities {
        let caps = borrow_global<Capabilities<CoinType>>(signer::address_of(coin_admin));
        coin::mint(amount, &caps.mint_cap)
    }

    public fun burn<CoinType>(coin_admin: &signer, coins: Coin<CoinType>) acquires Capabilities {
        if (coin::value(&coins) == 0) {
            coin::destroy_zero(coins);
        } else {
            let caps = borrow_global<Capabilities<CoinType>>(signer::address_of(coin_admin));
            coin::burn(coins, &caps.burn_cap);
        };
    }
}
