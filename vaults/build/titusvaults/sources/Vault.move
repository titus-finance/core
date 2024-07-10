module titusvaults::Vault {
    // use std::signer;
    use aptos_framework::coin::{Self, Coin};
    use std::signer::address_of;
    // use aptos_std::big_vector::borrow;
    use aptos_std::smart_table::{Self, SmartTable};
    // use aptos_framework::account;
    // use aptos_framework::randomness::u64_integer;
    use aptos_framework::timestamp;

    /// When signer is not owner of module
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_INVALID_OPERATION: u64 = 2;
    const E_NOT_INSTANT_WITHDRAWAL: u64 = 3;
    const E_NOT_STANDARD_WITHDRAWAL: u64 = 4;
    const E_NOT_ENOUGH_DEPOSIT: u64 = 5;

    struct CurrentRound has key {
        intial_time: u64,
        round: u64,
    }

    struct Vault <phantom VaultT, phantom AssetT> has key {
        coin_store: Coin<AssetT>,
        creation_time: u64,
        creation_round: u64,
    }

    struct VaultMap <phantom VaultT, phantom AssetT> has key {
        deposits: SmartTable<address, u64>,
        total_vaults: u64,
    }

    public entry fun set_current_time(_host: &signer) {
        let host_addr = address_of(_host);
        assert!(host_addr == @titusvaults, E_NOT_AUTHORIZED);
        move_to(_host, CurrentRound {
            intial_time: timestamp::now_microseconds(),
            round: 0,
        });
    }

    entry fun update_current_round(_host: &signer) acquires CurrentRound{
        let host_addr = address_of(_host);
        assert!(host_addr == @titusvaults, E_NOT_AUTHORIZED);

        let current_round_struct = borrow_global<CurrentRound>(@titusvaults);
        while (true) {
            let new_current_round = timestamp::now_microseconds() - current_round_struct.intial_time/7200;
            move_to(_host, CurrentRound{
                intial_time: current_round_struct.intial_time,
                round: new_current_round,
            });
        }
    }

    /// to create new vaults for Nth round
    public fun create_vault<VaultT, AssetT>(_host: &signer) acquires CurrentRound {
        let host_addr = address_of(_host);
        assert!(host_addr == @titusvaults, E_NOT_AUTHORIZED);

        let current_round = borrow_global<CurrentRound>(@titusvaults);
        if (!exists<VaultMap<VaultT, AssetT>>(host_addr)) {
            move_to(_host, VaultMap<VaultT, AssetT> {
                deposits: smart_table::new(),
                total_vaults: 0,
            });
            move_to(_host, Vault<VaultT, AssetT> {
                coin_store: coin::zero(),
                creation_time: timestamp::now_microseconds(),
                creation_round: current_round.round,
            });
        };
    }

    public fun vault_balance<VaultT, AssetT>(): u64 acquires Vault {
        let vault = borrow_global_mut<Vault<VaultT, AssetT>>(@titusvaults);
        coin::value(&vault.coin_store)
    }

    public (friend) fun deposit_vault<VaultT, AssetT>( account: &signer, _coin: Coin<AssetT>) acquires Vault, VaultMap {
        let user_addr = address_of(account);
        let vault = borrow_global_mut<Vault<VaultT, AssetT>>(@titusvaults);
        let vault_map = borrow_global_mut<VaultMap<VaultT, AssetT>>(@titusvaults);

        if (smart_table::contains(&vault_map.deposits, user_addr)) {
            let current_deposit = *smart_table::borrow(&mut vault_map.deposits, user_addr);
            let new_coin = current_deposit + coin::value(&_coin); //Not able to fetch and add the new coin detail
            smart_table::upsert(&mut vault_map.deposits, user_addr, new_coin);
        } else {
            smart_table::add(&mut vault_map.deposits, user_addr, coin::value(&_coin));
        };
        coin::merge(&mut vault.coin_store, _coin);
    }

    public (friend) fun instant_withdraw_vault<VaultT, AssetT>(account: &signer, amount: u64) acquires CurrentRound, Vault, VaultMap{
        let user_addr = address_of(account);
        let vault = borrow_global_mut<Vault<VaultT, AssetT>>(@titusvaults);
        let vault_map = borrow_global_mut<VaultMap<VaultT, AssetT>>(@titusvaults);

        let current_round = borrow_global<CurrentRound>(@titusvaults);

        let current_deposit = *smart_table::borrow(&mut vault_map.deposits, user_addr);
        assert!(current_round.round == vault.creation_round, E_NOT_INSTANT_WITHDRAWAL);
        assert!(current_deposit>=amount, E_NOT_ENOUGH_DEPOSIT);
        coin::deposit(user_addr, coin::extract(&mut vault.coin_store, amount));
        if (current_deposit == amount){
            smart_table::remove(&mut vault_map.deposits, user_addr);
        };
    }

    public (friend) fun standard_withdraw_vault<VaultT, AssetT>(account: &signer,  amount: u64) acquires CurrentRound, Vault, VaultMap{
        let user_addr = address_of(account);
        let vault = borrow_global_mut<Vault<VaultT, AssetT>>(@titusvaults);
        let vault_map = borrow_global_mut<VaultMap<VaultT, AssetT>>(@titusvaults);

        let current_round = borrow_global<CurrentRound>(@titusvaults);

        let current_deposit = *smart_table::borrow(&mut vault_map.deposits, user_addr);
        assert!(current_round.round >= vault.creation_round + 2, E_NOT_STANDARD_WITHDRAWAL);
        assert!(current_deposit>=amount, E_NOT_ENOUGH_DEPOSIT);
        coin::deposit(user_addr, coin::extract(&mut vault.coin_store, amount));
        if (current_deposit == amount){
            smart_table::remove(&mut vault_map.deposits, user_addr);
        };
    }


    // #[test]
    // fun test_deposit() {
    //     use aptos_framework::coin;
    //     use aptos_framework::aptos_coin::AptosCoin;
    //
    //     // Set up the test environment
    //     let account = signer::new_signer(0x1);
    //
    //     // Publish the AptosCoin and Vault resources
    //     coin::initialize<AptosCoin>(&account, 100_000_000);
    //     create_vault(&account);
    //
    //     // Deposit some AptosCoin into the vault
    //     deposit(&account, 10_000);
    //
    //     // Check the balance in the vault
    //     let balance = get_balance(signer::address_of(&account));
    //     assert!(balance == 10_000, 42);
    // }
}