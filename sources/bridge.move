module mover::bridge {
    use std::signer;
    use std::string::{String};
    use std::error;

    use aptos_framework::coin::{Self, MintCapability, BurnCapability};
    use aptos_framework::event;
    use aptos_std::type_info;
    use aptos_std::event::EventHandle;
    use aptos_framework::account;
    use aptos_std::table::Table;
    use aptos_std::type_info::TypeInfo;
    use aptos_std::table;
    use mover::liquidity_pool;
    use mover::chains::{Arbitrum, Ethereum, BSC, Polygon, Optimism};

    const HUNDRED : u128 = 100 * 1000000;
    const DEFAULT_FEE: u128 = 130000; // 13% = 130000, 10% = 100000

    const EACCESS_DENIED: u64 = 10;
    const ENOT_IN_WL: u64 = 20;
    const ENOT_IN_RELAYER_LIST: u64 = 30;
    const EBAD_NONCE: u64 = 40;
    const EUKNOWN_COIN_TYPE: u64 = 50;
    const ECOIN_NOT_REGISTERED: u64 = 60;
    const ECOIN_ALREADY_REGISTERED: u64 = 70;
    const EINSUFFICIENT_LIQUIDITY: u64 = 80;
    const ELIMIT_EXCEEDED: u64 = 90;
    const ECOIN_NOT_INITIALIZED: u64 = 100;

    struct Caps<phantom CoinType> has key {
        mint: MintCapability<CoinType>,
        burn: BurnCapability<CoinType>,
    }

    struct SwapInEvent has drop, store {
        amount: u64,
        from: String,
        to: address,
        src_chain: u64,
        nonce: u128,
    }

    struct SwapOutEvent has drop, store {
        amount: u64,
        from: address,
        to: String,
        dest_chain: u64,
        nonce: u128,
    }

    struct BridgeEvents<phantom CoinType> has key {
        swapin_events: EventHandle<SwapInEvent>,
        swapout_events: EventHandle<SwapOutEvent>,
    }

    struct RelayersHolder has key {
        relayers: Table<address, bool>
    }

    const NATIVE_COIN: u64 = 1;
    const WRAPPED_COIN: u64 = 2;

    struct BridgeSettings<phantom Chain> has key {
        fee_perc: u128,
        swap_in_nonce: Table<u128, bool>,
        supported_coins: Table<TypeInfo, u64>,
        nonce: u128,
        paused: bool,
    }

    fun only_owner(caller: &signer) {
        let account_addr = signer::address_of(caller);
        assert!(
            @mover == account_addr,
            error::permission_denied(EACCESS_DENIED),
        );
    }

    public entry fun add_wrapped_coin<Coin>(
        account: &signer,
        name: String,
        symbol: String,
        decimals: u8,
    ) {
        only_owner(account);
        let (burn, freeze, mint) =
            coin::initialize<Coin>(
                account,
                name,
                symbol, decimals,
                true);
        coin::destroy_freeze_cap(freeze);
        move_to(account, Caps<Coin> {mint, burn});

        move_to(account, BridgeEvents<Coin> {
            swapin_events: account::new_event_handle<SwapInEvent>(account),
            swapout_events: account::new_event_handle<SwapOutEvent>(account),
        });
    }

    public entry fun enable_coin<Coin, Chain>(
        account: &signer
    ) acquires BridgeSettings {
        only_owner(account);
        let settings = borrow_global_mut<BridgeSettings<Chain>>(@mover);
        let coin_type_info = type_info::type_of<Coin>();
        assert!(
            !table::contains(&settings.supported_coins, coin_type_info),
            ECOIN_ALREADY_REGISTERED
        );
        table::add(&mut settings.supported_coins, type_info::type_of<Coin>(), NATIVE_COIN);
    }

    public entry fun add_native_coin<Coin>(
        account: &signer,
    ) {
        only_owner(account);
        assert!(coin::is_coin_initialized<Coin>(), ECOIN_NOT_INITIALIZED);

        liquidity_pool::register<Coin>(account);

        move_to(account, BridgeEvents<Coin> {
            swapin_events: account::new_event_handle<SwapInEvent>(account),
            swapout_events: account::new_event_handle<SwapOutEvent>(account),
        });
    }

    public entry fun remove_coin<Coin, Chain>(account: &signer) acquires BridgeSettings{
        only_owner(account);
        let settings = borrow_global_mut<BridgeSettings<Chain>>(@mover);
        table::remove(&mut settings.supported_coins, type_info::type_of<Coin>());
    }

    public entry fun setFee<Chain>(token_admin: &signer, _fee_perc: u128) acquires BridgeSettings {
        only_owner(token_admin);
        let fee_perc = &mut borrow_global_mut<BridgeSettings<Chain>>(@mover).fee_perc;
        *fee_perc =  _fee_perc;
    }

    public fun get_nonce<Chain>(): u128 acquires BridgeSettings {
        borrow_global<BridgeSettings<Chain>>(@mover).nonce
    }

    public entry fun pause_chain<Chain>(admin: &signer) acquires BridgeSettings {
        only_owner(admin);
        let settings = borrow_global_mut<BridgeSettings<Chain>>(@mover);
        *(&mut settings.paused) = true;
    }

    public entry fun add_chain<Chain>(admin: &signer) {
        only_owner(admin);
        let swap_in_nonce = table::new<u128, bool>();
        let supported_coins = table::new<TypeInfo, u64>();
        move_to(admin, BridgeSettings<Chain> {
            fee_perc: DEFAULT_FEE,
            swap_in_nonce,
            supported_coins,
            nonce: 0,
            paused: false,
        });
    }

    public entry fun initialize(admin: &signer) acquires RelayersHolder {
        only_owner(admin);
        let relayers = table::new<address, bool>();
        move_to(admin, RelayersHolder { relayers });
        add_to_relayers_list(admin, @mover);
        add_chain<Arbitrum>(admin);
        add_chain<Ethereum>(admin);
        add_chain<BSC>(admin);
        add_chain<Polygon>(admin);
        add_chain<Optimism>(admin);
    }

    fun coin_address<CoinType>(): address {
        let type_info = type_info::type_of<CoinType>();
        type_info::account_address(&type_info)
    }

    fun relayers_address<RelayersHolder>(): address {
        let type_info = type_info::type_of<RelayersHolder>();
        type_info::account_address(&type_info)
    }

    public entry fun add_to_relayers_list(
        account: &signer,
        address: address,
    )  acquires RelayersHolder {
        only_owner(account);
        let account_addr = signer::address_of(account);
        let relayers_ref = &mut borrow_global_mut<RelayersHolder>(account_addr).relayers;
        table::upsert(relayers_ref, address, true);
    }

    fun is_relayer(account: address): bool acquires RelayersHolder {
        let relayers_ref = &borrow_global<RelayersHolder>(
            relayers_address<RelayersHolder>()
        ).relayers;
        table::contains(relayers_ref, account)
    }

    public fun get_coin_type<CoinType, Chain>(bridge_settings: &BridgeSettings<Chain>): u64 {
        assert!(
            table::contains(&bridge_settings.supported_coins,type_info::type_of<CoinType>()),
            error::permission_denied(ECOIN_NOT_REGISTERED)
        );
        *table::borrow(&bridge_settings.supported_coins,type_info::type_of<CoinType>())
    }

    public entry fun swap_in<CoinType, Chain>(
        account: &signer,
        amount: u64,
        from: String,
        to: address,
        src_chain: u64,
        nonce: u128,
    )  acquires Caps, BridgeEvents, RelayersHolder, BridgeSettings {
        let account_addr = signer::address_of(account);
        assert!(
            is_relayer(account_addr),
            error::permission_denied(EACCESS_DENIED),
        );

        let bridge_settings= borrow_global_mut<BridgeSettings<Chain>>(@mover);
        assert!(
            !table::contains(&bridge_settings.swap_in_nonce, nonce),
            error::permission_denied(EBAD_NONCE)
        );

        let type = get_coin_type<CoinType, Chain>(bridge_settings);
        if (type == NATIVE_COIN) {
            assert!(liquidity_pool::reserves<CoinType>() >= amount, EINSUFFICIENT_LIQUIDITY);
            coin::deposit(to, liquidity_pool::release<CoinType>(account,amount));
        } else if (type == WRAPPED_COIN) {
            let caps = borrow_global<Caps<CoinType>>(@mover);
            let mintedCoins = coin::mint<CoinType>(amount, &caps.mint);
            coin::deposit(to, mintedCoins);
        };

        let bridge_events= borrow_global_mut<BridgeEvents<CoinType>>(@mover);
        event::emit_event<SwapInEvent>(
             &mut bridge_events.swapin_events,
            SwapInEvent {
                src_chain,
                from,
                to,
                amount,
                nonce,
            },
        );
        table::upsert(&mut bridge_settings.swap_in_nonce, nonce, true);
    }

    public entry fun swap_out<CoinType, Chain>(
        account: &signer,
        amount: u64,
        to: String,
        dest_chain: u64,
    ) acquires Caps, BridgeEvents, BridgeSettings {

        let bridge_settings = borrow_global_mut<BridgeSettings<Chain>>(@mover);
        let type = get_coin_type<CoinType, Chain>(bridge_settings);
        let coins_out = coin::withdraw<CoinType>(account, amount);

        if (type == NATIVE_COIN) {
            liquidity_pool::lock(coins_out);
        } else {
            let caps = borrow_global<Caps<CoinType>>(@mover);
            coin::burn<CoinType>(coins_out, &caps.burn);
        };

        let bridge_events = borrow_global_mut<BridgeEvents<CoinType>>(
            @mover
        );

        let fee_amount = ((((amount as u128) * bridge_settings.fee_perc) / HUNDRED) as u64);
        event::emit_event<SwapOutEvent>(
             &mut bridge_events.swapout_events,
            SwapOutEvent {
                dest_chain,
                from: signer::address_of(account),
                to,
                amount: amount - fee_amount,
                nonce: bridge_settings.nonce
            },
        );

        *(&mut bridge_settings.nonce) = bridge_settings.nonce + 1;
    }
}
