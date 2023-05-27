#[test_only]
module mover::wrapped_coins {
    use aptos_framework::coin;
    use std::string::utf8;
    use aptos_framework::coin::{MintCapability, BurnCapability, Coin};
    use std::signer;
    struct MoverUSDC {}
    struct MoverUSDT {}

    struct Capabilities<phantom CoinType> has key {
        mint_cap: MintCapability<CoinType>,
        burn_cap: BurnCapability<CoinType>,
    }


    public fun register_coins(mover_admin: &signer) {
        let (moverUSDC_burn_cap,
            moverUSDC_freeze_cap,
            moverUSDC_mint_cap) =
            coin::initialize<MoverUSDC>(
                mover_admin,
                utf8(b"moverUSDC"),
                utf8(b"moverUSDC"),
                6,
                true
            );
        let (moverUSDT_burn_cap,
            moverUSDT_freeze_cap,
            moverUSDT_mint_cap) =
            coin::initialize<MoverUSDT>(
                mover_admin,
                utf8(b"moverUSDT"),
                utf8(b"moverUSDT"),
                6,
                true
            );


        move_to(mover_admin, Capabilities<MoverUSDC> {
            mint_cap: moverUSDC_mint_cap,
            burn_cap: moverUSDC_burn_cap,
        });
        move_to(mover_admin, Capabilities<MoverUSDT> {
            mint_cap: moverUSDT_mint_cap,
            burn_cap: moverUSDT_burn_cap,
        });

        coin::destroy_freeze_cap(moverUSDC_freeze_cap);
        coin::destroy_freeze_cap(moverUSDT_freeze_cap);
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