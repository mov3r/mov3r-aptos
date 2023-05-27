module mover::liquidity_pool {
    use std::signer;

    use aptos_framework::event;
    use aptos_framework::account::{Self};
    use aptos_framework::coin::{Self, Coin};

    use std::string;
    use std::string::String;

    struct LPCoin<phantom CoinType> {}

    struct LiquidityPool<phantom CoinType> has key {
        native_reserve: Coin<CoinType>,
        lp_mint_cap: coin::MintCapability<LPCoin<CoinType>>,
        lp_burn_cap: coin::BurnCapability<LPCoin<CoinType>>,
    }

    struct EventsStore<phantom CoinType> has key {
        pool_created_handle: event::EventHandle<PoolCreatedEvent<CoinType>>,
        liquidity_provided_handle: event::EventHandle<LiquidityProvidedEvent<CoinType>>,
        liquidity_removed_handle: event::EventHandle<LiquidityRemovedEvent<CoinType>>,
    }

    struct PoolCreatedEvent<phantom CoinType> has drop, store {
        creator: address,
    }

    struct LiquidityProvidedEvent<phantom CoinType> has drop, store {
        added_val: u64,
        lp_tokens_received: u64,
    }

    struct LiquidityRemovedEvent<phantom CoinType> has drop, store {
        removed_val: u64,
        lp_tokens_burned: u64,
    }

    const EACCESS_DENIED: u64 = 100;
    const EPOOL_DOES_NOT_EXIST: u64 = 210;
    const EZERO_LIQUIDITY: u64 = 400;
    const EZERO_AMOUNT: u64 = 500;

    const SYMBOL_PREFIX_LENGTH: u64 = 10;
    const NAME_PREFIX_LENGTH: u64 = 32;

    public fun register<CoinType>(lp_admin: &signer) {
        assert!(signer::address_of(lp_admin) == @mover, EACCESS_DENIED);

        let (lp_name, lp_symbol) = generate_lp_name_and_symbol<CoinType>();
        let (
            lp_burn_cap,
            lp_freeze_cap,
            lp_mint_cap
        ) =
            coin::initialize<LPCoin<CoinType>>(
                lp_admin,
                lp_name,
                lp_symbol,
                coin::decimals<CoinType>(),
                true
            );
        coin::destroy_freeze_cap(lp_freeze_cap);

        let pool = LiquidityPool<CoinType> {
            native_reserve: coin::zero<CoinType>(),
            lp_mint_cap,
            lp_burn_cap,
        };
        move_to(lp_admin, pool);

        let events_store = EventsStore<CoinType> {
            pool_created_handle: account::new_event_handle(lp_admin),
            liquidity_provided_handle: account::new_event_handle(lp_admin),
            liquidity_removed_handle: account::new_event_handle(lp_admin),
        };
        event::emit_event(
            &mut events_store.pool_created_handle,
            PoolCreatedEvent<CoinType> {
                creator: signer::address_of(lp_admin)
            },
        );
        move_to(lp_admin, events_store);
    }

    public entry fun provide_liquidity<CoinType>(
        lp_provider: &signer,
        amount: u64,
    ) acquires LiquidityPool, EventsStore {
        assert!(amount > 0, EZERO_AMOUNT);

        let coin_y = coin::withdraw<CoinType>(lp_provider, amount);
        let lp_coins = mint_lp_coins<CoinType>(coin_y);
        let lp_provider_address = signer::address_of(lp_provider);
        if (!coin::is_account_registered<LPCoin<CoinType>>(lp_provider_address)) {
            coin::register<LPCoin<CoinType>>(lp_provider);
        };
        coin::deposit(lp_provider_address, lp_coins);
    }

    public fun mint_lp_coins<CoinType>(
        coin: Coin<CoinType>
    ): Coin<LPCoin<CoinType>> acquires LiquidityPool, EventsStore {
        let provided_val = lock<CoinType>(coin);
        let pool = borrow_global_mut<LiquidityPool<CoinType>>(@mover);

        let lp_coins = coin::mint<LPCoin<CoinType>>(provided_val, &pool.lp_mint_cap);
        let events_store = borrow_global_mut<EventsStore<CoinType>>(@mover);
        event::emit_event(
            &mut events_store.liquidity_provided_handle,
            LiquidityProvidedEvent<CoinType> {
                added_val: provided_val,
                lp_tokens_received: provided_val
            });
        lp_coins
    }

    public entry fun withdraw_liquidity<CoinType>(
        lp_provider: &signer,
        amount: u64
    ) acquires LiquidityPool, EventsStore {
        assert!(amount > 0, EZERO_AMOUNT);

        let lp_coins = coin::withdraw<LPCoin<CoinType>>(lp_provider, amount);
        let coins = burn<CoinType>(lp_coins);
        let lp_provider_address = signer::address_of(lp_provider);
        if (!coin::is_account_registered<CoinType>(lp_provider_address)) {
            coin::register<CoinType>(lp_provider);
        };
        coin::deposit(lp_provider_address, coins);
    }

    public fun burn<CoinType>(lp_coins: Coin<LPCoin<CoinType>>): Coin<CoinType> acquires LiquidityPool, EventsStore {
        assert!(exists<LiquidityPool<CoinType>>(@mover), EPOOL_DOES_NOT_EXIST);

        let burned_lp_coins_val = coin::value(&lp_coins);
        let pool = borrow_global_mut<LiquidityPool<CoinType>>(@mover);

        let coins_to_return = coin::extract(&mut pool.native_reserve, burned_lp_coins_val);
        coin::burn(lp_coins, &pool.lp_burn_cap);

        let events_store = borrow_global_mut<EventsStore<CoinType>>(@mover);
        event::emit_event(
            &mut events_store.liquidity_removed_handle,
            LiquidityRemovedEvent<CoinType> {
                removed_val: burned_lp_coins_val,
                lp_tokens_burned: burned_lp_coins_val
            });
        coins_to_return
    }

    public entry fun emergency_withdraw<CoinType>(admin: &signer, amount: u64) acquires LiquidityPool {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @mover, EACCESS_DENIED);
        assert!(amount > 0, EZERO_AMOUNT);

        let pool = borrow_global_mut<LiquidityPool<CoinType>>(@mover);
        let coins_to_return = coin::extract(&mut pool.native_reserve, amount);
        if (!coin::is_account_registered<CoinType>(admin_addr)) {
            coin::register<CoinType>(admin);
        };
        coin::deposit(admin_addr, coins_to_return);
    }

    public fun lock<CoinType>(coin: Coin<CoinType>): u64 acquires LiquidityPool {
        assert!(exists<LiquidityPool<CoinType>>(@mover), EPOOL_DOES_NOT_EXIST);
        let pool = borrow_global_mut<LiquidityPool<CoinType>>(@mover);

        let provided_val = coin::value<CoinType>(&coin);
        assert!(provided_val > 0, EZERO_LIQUIDITY);

        coin::merge(&mut pool.native_reserve, coin);
        provided_val
    }

    public fun release<CoinType>(admin: &signer, amount: u64): Coin<CoinType> acquires LiquidityPool {
        assert!(
            signer::address_of(admin) == @mover || signer::address_of(admin) == @mover,
            EACCESS_DENIED);

        assert!(exists<LiquidityPool<CoinType>>(@mover), EPOOL_DOES_NOT_EXIST);
        let pool = borrow_global_mut<LiquidityPool<CoinType>>(@mover);

        // Withdraw those values from reserves
        coin::extract(&mut pool.native_reserve, amount)
    }

    public fun reserves<CoinType>(): u64 acquires LiquidityPool {
        assert!(exists<LiquidityPool<CoinType>>(@mover), EPOOL_DOES_NOT_EXIST);

        let liquidity_pool = borrow_global<LiquidityPool<CoinType>>(@mover);
        coin::value(&liquidity_pool.native_reserve)
    }

    public fun generate_lp_name_and_symbol<CoinType>(): (String, String) {
        let lp_name = string::utf8(b"LP-");
        string::append(&mut lp_name, coin::name<CoinType>());
        let lp_symbol = string::utf8(b"LP-");
        string::append(&mut lp_symbol, coin::symbol<CoinType>());
        (prefix(lp_name, NAME_PREFIX_LENGTH), prefix(lp_name, SYMBOL_PREFIX_LENGTH))
    }

    public fun min_u64(a: u64, b: u64): u64 {
        if (a < b) a else b
    }

    fun prefix(str: String, max_len: u64): String {
        let prefix_length = min_u64(string::length(&str), max_len);
        string::sub_string(&str, 0, prefix_length)
    }
}
