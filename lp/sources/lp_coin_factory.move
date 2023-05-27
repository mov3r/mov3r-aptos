module mover::lp_coin_factory {
    use std::signer;

    use aptos_framework::account::{Self, SignerCapability};

    const EACCESS_DENIED: u64 = 2500;

    struct CapabilityStorage has key { signer_cap: SignerCapability }

    public entry fun deploy_resource_account(
        lp_admin: &signer,
        seed: vector<u8>,
        metadata: vector<u8>,
        code: vector<vector<u8>>
    ) {
        assert!(signer::address_of(lp_admin) == @mover, EACCESS_DENIED);

        let (lp_acc, signer_cap) =
            account::create_resource_account(lp_admin, seed);
        aptos_framework::code::publish_package_txn(
            &lp_acc,
            metadata,
            code
        );
        move_to(lp_admin, CapabilityStorage { signer_cap });
    }

    public fun withrdaw_admin_signer_cap(lp_admin: &signer): SignerCapability acquires CapabilityStorage {
        assert!(signer::address_of(lp_admin) == @mover, EACCESS_DENIED);
        let CapabilityStorage { signer_cap } =
            move_from<CapabilityStorage>(signer::address_of(lp_admin));
        signer_cap
    }
}
