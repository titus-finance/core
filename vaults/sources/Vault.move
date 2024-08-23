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
        round: u64
    }

    struct Vault <phantom VaultT, phantom AssetT> has key {
        coin_store: Coin<AssetT>,
        creation_time: u64,
        creation_round: u64,
        total_shares: u64
    }

    struct VaultMap <phantom VaultT, phantom AssetT> has key {
        deposits: SmartTable<address, u64>,
        shares: SmartTable<address, u64>,
        total_vaults: u64
    }

    // events
    struct DepositVaultEvent {
        depositor: address,
        amount: u64,
        shares_minted: u64
    }

    struct InstantWithdrawVaultEvent {
        withdrawer: address,
        amount: u64,
        shares_burnt: u64,
    }

    public entry fun set_current_time(_host: &signer) {
        let host_addr = address_of(_host);
        assert!(host_addr == @titusvaults, E_NOT_AUTHORIZED);
        move_to(_host, CurrentRound {
            intial_time: timestamp::now_microseconds(),
            round: 0,
        });
    }

    entry fun update_round(_host: &signer) acquires CurrentRound {
        let host_addr = address_of(_host);
        assert!(host_addr == @titusvaults, E_NOT_AUTHORIZED);

        let current_round_struct = borrow_global_mut<CurrentRound>(@titusvaults);
        let new_current_round = (timestamp::now_microseconds() - current_round_struct.intial_time) / 7200;

        current_round_struct.round = new_current_round;
    }

    /// to create new vaults for Nth round
    public fun create_vault<VaultT, AssetT>(_host: &signer) acquires CurrentRound {
        let host_addr = address_of(_host);
        assert!(host_addr == @titusvaults, E_NOT_AUTHORIZED);

        let current_round = borrow_global<CurrentRound>(@titusvaults);
        if (!exists<VaultMap<VaultT, AssetT>>(host_addr)) {
            move_to(_host, VaultMap<VaultT, AssetT> {
                deposits: smart_table::new(),
                shares: smart_table::new(),
                total_vaults: 0,
            });
            move_to(_host, Vault<VaultT, AssetT> {
                coin_store: coin::zero(),
                creation_time: timestamp::now_microseconds(),
                creation_round: current_round.round,
                total_shares: 0,
            });
        };
    }

    public (friend) fun deposit_vault<VaultT, AssetT>( account: &signer, _coin: Coin<AssetT>) acquires Vault, VaultMap {
        let user_addr = address_of(account);
        let vault = borrow_global_mut<Vault<VaultT, AssetT>>(@titusvaults);
        let vault_map = borrow_global_mut<VaultMap<VaultT, AssetT>>(@titusvaults);
        let coin_value = coin::value(&_coin);

        // mint shares
        let shares_to_mint = if(vault.total_shares == 0) {
            // a = s
            coin_value
        } else {
            // aT / B = s
            (coin_value * vault.total_shares) / coin::value(&vault.coin_store)
        };

        if (smart_table::contains(&vault_map.deposits, user_addr)) {
            let current_deposit = *smart_table::borrow(&mut vault_map.deposits, user_addr);
            let current_shares = *smart_table::borrow(&mut vault_map.shares, user_addr);
            let new_coin = current_deposit + coin_value; //Not able to fetch and add the new coin detail 

            smart_table::upsert(&mut vault_map.deposits, user_addr, new_coin);
            smart_table::upsert(&mut vault_map.shares, user_addr, current_shares + shares_to_mint);        
        } else {
            smart_table::add(&mut vault_map.deposits, user_addr, coin_value);
            smart_table::add(&mut vault_map.shares, user_addr, shares_to_mint);
        };
        
        // update vault total shares
        vault.total_shares += shares_to_mint;

        // merge deposited coins into the vault coin store
        coin::merge(&mut vault.coin_store, _coin);

        // deposit vault event
        let deposit_vault_event = DepositVaultEvent {
            depositor: user_addr,
            amount: coin_value,
            shares_minted: shares_to_mint,
        };
        event::emit(deposit_vault_event);
    }

    public (friend) fun instant_withdraw_vault<VaultT, AssetT>(account: &signer, amount: u64) acquires CurrentRound, Vault, VaultMap {
        let user_addr = address_of(account);
        let user_shares = *smart_table::borrow(&vault_map.shares, user_addr);

        let vault = borrow_global_mut<Vault<VaultT, AssetT>>(@titusvaults);
        let vault_map = borrow_global_mut<VaultMap<VaultT, AssetT>>(@titusvaults);

        let current_round = borrow_global<CurrentRound>(@titusvaults);

        let current_deposit = *smart_table::borrow(&mut vault_map.deposits, user_addr);
        assert!(current_round.round == vault.creation_round, E_NOT_INSTANT_WITHDRAWAL);
        assert!(current_deposit >= amount, E_NOT_ENOUGH_DEPOSIT);

        // calculate shares to burn
        let shares_to_burn = (amount * user_shares) / current_deposit;
  
        // update user deposit and shares
        let new_deposit = current_deposit - amount;
        let new_shares = user_shares - shares_to_burn;

        smart_table::upsert(&mut vault_map.deposits, user_addr, new_deposit);    
        smart_table::upsert(&mut vault_map.shares, user_addr, new_shares);
        
        // perform the coin transfer
        coin::withdraw(&mut vault.coin_store, amount);
        coin::deposit(user_addr, coin::extract(&mut vault.coin_store, amount));

        // update vault total shares
        vault.total_shares -= shares_to_burn;

        // remove user from table if all shares are burned
        if new_shares == 0 {
            smart_table::remove(&mut vault_map.shares, user_addr);
        }

        // instant withdrawal vault event
        let instant_withdraw_vault_event = InstantWithdrawVaultEvent {
            user: user_addr,
            amount: amount,
            shares_burnt: shares_to_burn
        };
        event::emit(instant_withdraw_vault_event);
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

    #[view]
    public fun current_round(): u64 acquires CurrentRound {
        let current_round = borrow_global<CurrentRound>(@titusvaults);
        return current_round.round
    }

    #[view]
    public fun vault_balance<VaultT, AssetT>(): u64 acquires Vault {
        let vault = borrow_global_mut<Vault<VaultT, AssetT>>(@titusvaults);
        return coin::value(&vault.coin_store)
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
