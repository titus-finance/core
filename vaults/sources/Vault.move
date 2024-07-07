module titusvaults::Vault {
    use aptos_framework::coin::{Self, Coin};
    use std::signer;
    use std::signer::address_of;
    use aptos_framework::account;
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_framework::randomness::u64_integer;
    use aptos_framework::timestamp;

    /// When signer is not owner of module
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_INVALID_OPERATION: u64 = 69;

    struct Vault <phantom VaultT, phantom AssetT> has key {
        coin_store: Coin<AssetT>,
        creation_time: u64,
        creation_round: u64,
    }

    struct VaultMap <phantom VaultT, phantom AssetT> has key {
        deposits: SmartTable<address, Vault<VaultT, AssetT>>,
        total_vaults: u64,
    }

    struct CurrentRound has store {
        intial_time: u64,
        round: u64,
    }

    public entry fun set_current_time(_host: &signer) {
        let host_addr = address_of(_host);
        assert!(host_addr == @titusvaults, E_NOT_AUTHORIZED);
        CurrentRound {
            intial_time: timestamp::now_microseconds(),
            round: 0,
        };
    }

    /// to create new vaults for Nth round
    public fun create_vault<VaultT, AssetT>(_host: &signer) {
        let host_addr = address_of(_host);
        assert!(host_addr == @titusvaults, E_NOT_AUTHORIZED);

        let current_round = CurrentRound.round;
        if (!exists<VaultMap<VaultT, AssetT>>(host_addr)) {
            move_to(_host, VaultMap<VaultT, AssetT> {
                deposits: smart_table::new(),
                total_vaults: 0,
            });
            move_to(_host, Vault<VaultT, AssetT> {
                coin_store: coin::zero(),
                creation_time: timestamp::now_microseconds(),
                creation_round: current_round,
            });
        };
    }

    public fun vault_balance<VaultT, AssetT>(): u64 acquires Vault {
        let vault = borrow_global_mut<Vault<VaultT, AssetT>>(@titusvaults);
        coin::value(&vault.coin_store)
    }

    public (friend) fun deposit_vault<VaultT, AssetT>( account: &signer, _coin: Coin<AssetT>) acquires Vault, VaultMap {
        let user_addr = address_of(account);
        let vault = borrow_global<Vault<VaultT, AssetT>>(@titusvaults);
        let vault_map = borrow_global<VaultMap<VaultT, AssetT>>(@titusvaults);

        if (smart_table::contains(&vault_map.deposits, user_addr)) {
            let current_deposit = smart_table::borrow_mut(&mut vault_map.deposits, user_addr);
            let new_coin = (_coin); ///Not able to fetch the new coin detail
            smart_table::upsert(&mut vault_map.deposits, user_addr, Vault<VaultT, AssetT>{
                coin_store: new_coin,
                creation_time: timestamp::now_microseconds(),
                creation_round: CurrentRound.round,
            });
        } else {
            smart_table::add(&mut vault_map.deposits, user_addr, Vault<VaultT, AssetT>{
                coin_store: _coin,
                creation_time: timestamp::now_microseconds(),
                creation_round: CurrentRound.round,
            });
        };
        coin::merge(&mut vault.coin_store, _coin);
    }

    public (friend) fun withdraw_vault<VaultT, AssetT>(_amount: u64): Coin<AssetT> acquires Vault {
        if (CurrentRound.round == 0) {
            return coin::zero<AssetT>()
        };
        let vault = borrow_global_mut<Vault<VaultT, AssetT>>(@titusvaults);
        if (vault.vault_locked == true) {
            return coin::zero<AssetT>()
        };
        coin::extract(&mut vault.coin_store, _amount)
    }



    smart_table::add(&mut locks.locks, recipient, Lock {
    coins: staked_apt,
    principal,
    unlock_time_secs,
    })


    // public fun deposit_vault1 <AssetT>(account: &signer) {
    //     //TODO: ensure the account that is calling create_vault is authorized to do so
    //     // we'll have a vault per strategy, with differing underlying assets, strike prices etc
    //     // we also have to persist &signer's address somewhere for use in deposit/withdraw
    //     let init_deposits = smart_table::new<address, DepositBalance<AssetT>>();
    //     move_to(account, Vault { deposits: init_deposits });
    // }

    // TODO: this accepts Coin<AssetT> and joins it to the deposit balance
    // but we may want to store balances in global storage instead of the Coins

    // public fun deposit<AssetT>(account: &signer, amount: Coin<AssetT>, vault_addr: address) acquires Vault {
    //     let callee_address = signer::address_of(account);
    //     let vault = borrow_global_mut<Vault<AssetT>>(vault_addr);
    //     // check first if the callee of this function already exists in our vault's deposits
    //     if (smart_table::contains(&vault.deposits, callee_address)) {
    //         let curr_deposit = smart_table::borrow_mut<address, DepositBalance<AssetT>>(&mut vault.deposits, callee_address);
    //         coin::merge(&mut curr_deposit.balance, amount);
    //     } else {
    //         // we create the deposit for the user in our map
    //         smart_table::add<address, DepositBalance<AssetT>>(&mut vault.deposits, callee_address, DepositBalance{balance: amount});
    //     }
    // }
    //
    // // TODO: this accepts Coin<AssetT> and joins it to the deposit balance
    // // but we may want to store balances in global storage instead of the Coins
    // // this function signature is inconsistent/different that deposit in that we accept amount as a u64
    //
    // // Note that we accept the vault_addr as an input_param for now, this probably will need to change, but is a "placeholder" for now
    // public fun withdraw<AssetT>(account: &signer, amount: u64, vault_addr: address) acquires Vault {
    //     let callee_address = signer::address_of(account);
    //     let vault = borrow_global_mut<Vault<AssetT>>(vault_addr);
    //     // check first if the callee of this function already exists in our vault's deposits
    //     // there is no real else case here -- we could throw an error saying the user doesn't have an existing deposit, and handle it on the frontend
    //
    //     if (smart_table::contains(&vault.deposits, callee_address)) {
    //         assert!(true, E_INVALID_OPERATION)
    //     };
    //     let curr_deposit = smart_table::borrow_mut<address, DepositBalance<AssetT>>(&mut vault.deposits, callee_address);
    //     let withdrew_coins = coin::extract(&mut curr_deposit.balance, amount);
    //     coin::deposit(callee_address, withdrew_coins);
    // }


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