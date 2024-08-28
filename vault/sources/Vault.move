module titusvaults::Vault {
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::event;
    use std::signer::address_of;
    // use aptos_std::big_vector::borrow;
    use aptos_std::smart_table::{Self, SmartTable};
    // use aptos_framework::randomness::u64_integer;
    use aptos_framework::timestamp;

    // --- phases ---
    const DEPOSIT_PHASE_DURATION: u64 = 7200000000; // 2 hours
    const OPTION_EXPIRY_DURATION: u64 = 7200000000; // 2 hours
    const EXERCISE_BUFFER: u64 = 3600000000; // 1 hour 


    // --- errors ---
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_INVALID_OPERATION: u64 = 2;
    const E_NOT_INSTANT_WITHDRAWAL: u64 = 3;
    const E_NOT_STANDARD_WITHDRAWAL: u64 = 4;
    const E_NOT_ENOUGH_DEPOSIT: u64 = 5;
    const E_VAULT_DOSE_NOT_EXIST: u64 = 6;
    const E_VAULT_BALANCE_INCORRECT: u64 = 7;
    const E_NOT_DEPOSIT_PHASE: u64 = 8;
    const E_NOT_BETWEEN_IN_DEPOSIT_AND_ACTIVE_PHASE: u64 = 9;

    // --- structs ---

    struct RoundState has key {
        round: u64,
        current_round_id: u64,
        shares: SmartTable<address, u64>,
        rounds: SmartTable<address, u64>, 
        strike_price: u64,
        premium_price: u64,
        round_start_time: u64,
        deposit_start_time: u64,
        option_creation_time: u64,
        exercise_time: u64,
        close_timestamp: u64,
        timestamps_set: bool
    }

    struct Vault<phantom VaultT, phantom AssetT> has key {
        coin_store: Coin<AssetT>,
        creation_time: u64,
        creation_round: u64,
        total_shares: u64
    }

    struct VaultMap<phantom VaultT, phantom AssetT> has key {
        deposits: SmartTable<address, u64>,
        total_rounds: u64
    }

    // --- events ---
    #[event]
    struct DepositVaultEvent has drop, store {
        depositor: address,
        amount: u64,
        shares_minted: u64,
        round: u64
    }

    #[event]
    struct InstantWithdrawVaultEvent has drop, store {
        withdrawer: address,
        amount: u64,
        shares_burnt: u64
    }

    #[event]
    struct StandardWithdrawVaultEvent has drop, store {
        withdrawer: address,
        amount: u64,
        shares_burnt: u64
    }

    #[event]
    struct RoundUpdatedEvent has drop, store {
        new_round_id: u64
    }

    #[event]
    struct StrikePriceUpdatedEvent has drop, store {
        round_id: u64,
        strike_price: u64
    }

    #[event]
    struct PremiumPriceUpdatedEvent has drop, store {
        round_id: u64,
        premium_price: u64
    }

    public entry fun initialize_round_state(_host: &signer) {
        move_to(_host, RoundState {
            round: 0,
            current_round_id: 1,
            shares: smart_table::new(),
            rounds: smart_table::new(),
            strike_price: 0,
            premium_price: 0,
            round_start_time: 0,
            deposit_start_time: 0,
            option_creation_time: 0,
            exercise_time: 0,
            close_timestamp: 0,
            timestamps_set: false
        });
    }
    
    // keeper functions
    public fun update_round_from_keeper<VaultT, AssetT>(_host: &signer) acquires RoundState, VaultMap {
        let host_addr = signer::address_of(_host);

        // perform the state update
        let state = borrow_global_mut<RoundState>(@titusvaults);
        let vault_map = borrow_global_mut<VaultMap<VaultT, AssetT>>(@titusvaults);
        state.current_round_id = state.current_round_id + 1;
        vault_map.total_rounds = vault_map.total_rounds + 1;

        // calculate the new round timestamps
        // set the timestamps only if they haven't been set already
        if (!state.timestamps_set) {
            state.deposit_start_time = timestamp::now_microseconds();
            state.option_creation_time = state.deposit_start_time + DEPOSIT_PHASE_DURATION;
            state.exercise_time = state.option_creation_time + OPTION_EXPIRY_DURATION;
            state.close_timestamp = state.exercise_time + EXERCISE_BUFFER;
            state.timestamps_set = true;
        };

        // round update event
        let update_event = RoundUpdatedEvent {
            new_round_id: state.current_round_id,
        };
        event::emit(update_event);
    }

    /// to create new vaults for Nth round
    public fun create_vault<VaultT, AssetT>(_host: &signer) acquires RoundState {
        let host_addr = address_of(_host);
        assert!(host_addr == @titusvaults, E_NOT_AUTHORIZED);

        let current_round = borrow_global<RoundState>(@titusvaults);
        if (!exists<VaultMap<VaultT, AssetT>>(host_addr)) {
            move_to(_host, VaultMap<VaultT, AssetT> {
                deposits: smart_table::new(),
                total_rounds: 0
            });
            move_to(_host, Vault<VaultT, AssetT> {
                coin_store: coin::zero(),
                creation_time: timestamp::now_microseconds(),
                creation_round: current_round.round,
                total_shares: 0
            });
        };
    }

    public (friend) fun deposit_vault<VaultT, AssetT>( account: &signer, _coin: Coin<AssetT>) acquires Vault, VaultMap, RoundState {
        let user_addr = address_of(account);
        let vault = borrow_global_mut<Vault<VaultT, AssetT>>(@titusvaults);
        let vault_map = borrow_global_mut<VaultMap<VaultT, AssetT>>(@titusvaults);
        let round_state = borrow_global_mut<RoundState>(@titusvaults);
        let coin_value = coin::value(&_coin);

        // assert we are during the deposit phase
        let current_time = timestamp::now_microseconds();
        let deposit_end_time = round_state.round_start_time + DEPOSIT_PHASE_DURATION;
        assert!(current_time <= deposit_end_time, E_NOT_DEPOSIT_PHASE);

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
            let current_shares = *smart_table::borrow(&mut round_state.shares, user_addr);
            let new_coin = current_deposit + coin_value; //Not able to fetch and add the new coin detail 

            smart_table::upsert(&mut vault_map.deposits, user_addr, new_coin);
            smart_table::upsert(&mut round_state.shares, user_addr, current_shares + shares_to_mint);      
        } else {
            smart_table::add(&mut vault_map.deposits, user_addr, coin_value);
            smart_table::add(&mut round_state.shares, user_addr, shares_to_mint);
            smart_table::add(&mut round_state.rounds, user_addr, round_state.round);  
        };
        
        // update vault total shares
        vault.total_shares = vault.total_shares + shares_to_mint;

        // merge deposited coins into the vault coin store
        coin::merge(&mut vault.coin_store, _coin);

        // deposit vault event
        let deposit_vault_event = DepositVaultEvent {
            depositor: user_addr,
            amount: coin_value,
            shares_minted: shares_to_mint,
            round: round_state.round
        };
        event::emit(deposit_vault_event);
    }

    public (friend) fun instant_withdraw_vault<VaultT, AssetT>(account: &signer, amount: u64) acquires RoundState, Vault, VaultMap {
        let user_addr = address_of(account);

        let round_state = borrow_global_mut<RoundState>(@titusvaults);
        let vault = borrow_global_mut<Vault<VaultT, AssetT>>(@titusvaults);
        let vault_map = borrow_global_mut<VaultMap<VaultT, AssetT>>(@titusvaults);
        let user_shares = *smart_table::borrow(&round_state.shares, user_addr);

        // assert we are during the deposit phase
        let current_time = timestamp::now_microseconds();
        let deposit_end_time = round_state.round_start_time + DEPOSIT_PHASE_DURATION;
        assert!(current_time <= deposit_end_time, E_NOT_DEPOSIT_PHASE);

        let current_deposit = *smart_table::borrow(&mut vault_map.deposits, user_addr);
        assert!(round_state.round == vault.creation_round, E_NOT_INSTANT_WITHDRAWAL);
        assert!(current_deposit >= amount, E_NOT_ENOUGH_DEPOSIT);

        // calculate shares to burn
        let shares_to_burn = (amount * user_shares) / current_deposit;
  
        // update user deposit and shares
        let new_deposit = current_deposit - amount;
        let new_shares = user_shares - shares_to_burn;

        smart_table::upsert(&mut vault_map.deposits, user_addr, new_deposit);    
        smart_table::upsert(&mut round_state.shares, user_addr, new_shares);
        
        // perform the coin transfer
        coin::deposit(user_addr, coin::extract(&mut vault.coin_store, amount));

        // update vault total shares
        vault.total_shares = vault.total_shares - shares_to_burn;

        // remove user from table if all shares are burned
        if (new_shares == 0) {
            smart_table::remove(&mut round_state.shares, user_addr);
        };

        // instant withdrawal vault event
        let instant_withdraw_vault_event = InstantWithdrawVaultEvent {
            withdrawer: user_addr,
            amount: amount,
            shares_burnt: shares_to_burn
        };
        event::emit(instant_withdraw_vault_event);
    }

    public (friend) fun standard_withdraw_vault<VaultT, AssetT>(account: &signer,  amount: u64) acquires RoundState, Vault, VaultMap {
        let user_addr = address_of(account);

        let round_state = borrow_global_mut<RoundState>(@titusvaults);
        let vault = borrow_global_mut<Vault<VaultT, AssetT>>(@titusvaults);
        let vault_map = borrow_global_mut<VaultMap<VaultT, AssetT>>(@titusvaults);
        let user_shares = *smart_table::borrow(&round_state.shares, user_addr);

        let current_deposit = *smart_table::borrow(&mut vault_map.deposits, user_addr);

        // assert that standard withdrawal can only occur after the execution phase
        assert!(round_state.round >= vault.creation_round + 2, E_NOT_STANDARD_WITHDRAWAL);
        assert!(current_deposit >= amount, E_NOT_ENOUGH_DEPOSIT);

        // calculate shares to burn
        let shares_to_burn = (amount * user_shares) / current_deposit;
  
        // update user deposit and shares
        let new_deposit = current_deposit - amount;
        let new_shares = user_shares - shares_to_burn;

        smart_table::upsert(&mut vault_map.deposits, user_addr, new_deposit);    
        smart_table::upsert(&mut round_state.shares, user_addr, new_shares);
        
        // perform the coin transfer
        coin::deposit(user_addr, coin::extract(&mut vault.coin_store, amount));

        // update vault total shares
        vault.total_shares = vault.total_shares - shares_to_burn;

        // remove user from table if all shares are burned
        if (new_shares == 0) {
            smart_table::remove(&mut round_state.shares, user_addr);
        };

        // standard withdrawal vault event
        let standard_withdraw_vault_event = StandardWithdrawVaultEvent {
            withdrawer: user_addr,
            amount: amount,
            shares_burnt: shares_to_burn
        };
        event::emit(standard_withdraw_vault_event);
    }

    // strick price
    public (friend) fun setStrikePrice(_host: &signer, round_id: u64, new_strike_price: u64) acquires RoundState {
        let host_addr = address_of(_host);
        assert!(host_addr == @titusvaults, E_NOT_AUTHORIZED);

        let state = borrow_global_mut<RoundState>(@titusvaults);

        // assert we are during the deposit phase
        let current_time = timestamp::now_microseconds();
        let deposit_end_time = state.round_start_time + DEPOSIT_PHASE_DURATION;
        assert!(current_time <= deposit_end_time, E_NOT_DEPOSIT_PHASE);

        state.strike_price = new_strike_price;

        let strike_price_updated_event = StrikePriceUpdatedEvent {
            round_id: state.current_round_id,
            strike_price: new_strike_price
        };
        event::emit(strike_price_updated_event);
    }

    // premium price 
    public (friend) fun setPremiumPrice(_host: &signer, round_id: u64, new_premium_price: u64) acquires RoundState {
        let host_addr = address_of(_host);
        assert!(host_addr == @titusvaults, E_NOT_AUTHORIZED);

        let state = borrow_global_mut<RoundState>(@titusvaults);

        // assert we are during the deposit phase and active phase
        let current_time = timestamp::now_microseconds();
        let deposit_end_time = state.round_start_time + DEPOSIT_PHASE_DURATION;
        let active_end_time = deposit_end_time + OPTION_EXPIRY_DURATION;
        assert!(current_time >= state.round_start_time && current_time <= active_end_time, E_NOT_BETWEEN_IN_DEPOSIT_AND_ACTIVE_PHASE);

        state.premium_price = new_premium_price;

        let premium_price_updated_event = PremiumPriceUpdatedEvent {
            round_id: state.current_round_id,
            premium_price: new_premium_price
        };
        event::emit(premium_price_updated_event);
    }

    // --- views functions ---
    #[view]
    public fun current_round(): u64 acquires RoundState {
        let current_round = borrow_global<RoundState>(@titusvaults);
        return current_round.round
    }

    #[view]
    public fun vault_balance<VaultT, AssetT>(): u64 acquires Vault {
        let vault = borrow_global_mut<Vault<VaultT, AssetT>>(@titusvaults);
        return coin::value(&vault.coin_store)
    }

    // --- tests ---
    #[test_only]
    use aptos_framework::aptos_coin::{Self, AptosCoin};
    use aptos_framework::account;
    use std::signer;

    #[test_only]
    fun setup() {
        timestamp::set_time_has_started_for_testing(&account::create_signer_for_test(@0x1));
    }
    #[test_only]
    fun get_user_balance(user: &signer): u64 {
        coin::balance<AptosCoin>(signer::address_of(user))
    }

    // test vault created
    #[test(titusvaults = @0xa2bf272177d0723a90cb462bb087309e84554245934445af0da21132ba798b59, user = @0x2)]
    fun test_vault(titusvaults: &signer, user: &signer) acquires RoundState {
        setup();

        // Initialize RoundState
        initialize_round_state(titusvaults);

        // create vault
        create_vault<AptosCoin, AptosCoin>(titusvaults);

        // assert vault is created
        assert!(exists<Vault<AptosCoin, AptosCoin>>(@titusvaults), E_VAULT_DOSE_NOT_EXIST)
    }

    // test deposit
    #[test(titusvaults = @0xa2bf272177d0723a90cb462bb087309e84554245934445af0da21132ba798b59, user = @0x2)]
    fun test_deposit(titusvaults: &signer, user: signer) acquires Vault, VaultMap, RoundState {
        setup();

        // Initialize RoundState
        initialize_round_state(titusvaults);

        // create vault
        create_vault<AptosCoin, AptosCoin>(titusvaults);

        // add 100 coins to the user
        let user_addr = signer::address_of(&user);
        let (burn, mint) = aptos_framework::aptos_coin::initialize_for_test(&account::create_signer_for_test(@0x1));
        aptos_framework::aptos_account::create_account(copy user_addr);
        let coin = coin::mint<AptosCoin>(100, &mint);
        coin::deposit(copy user_addr, coin);

        // user deposit the 100 coins into the vault
        let deposit_coin = coin::withdraw<AptosCoin>(&user, 100);
        deposit_vault<AptosCoin, AptosCoin>(&user, deposit_coin);

        // assert that vault balance is 100 coins
        assert!(vault_balance<AptosCoin, AptosCoin>() == 100, E_VAULT_BALANCE_INCORRECT);

        coin::destroy_burn_cap(burn);
        coin::destroy_mint_cap(mint);
    }

    // test instant withdraw vault
    #[test(titusvaults = @0xa2bf272177d0723a90cb462bb087309e84554245934445af0da21132ba798b59, user = @0x2)]
    fun test_instant_withdraw_vault(titusvaults: &signer, user: signer) acquires RoundState, Vault, VaultMap {
        setup();

        // Initialize RoundState
        initialize_round_state(titusvaults);

        // create vault
        create_vault<AptosCoin, AptosCoin>(titusvaults);

        // add 100 coins to the user
        let user_addr = signer::address_of(&user);
        let (burn, mint) = aptos_framework::aptos_coin::initialize_for_test(&account::create_signer_for_test(@0x1));
        aptos_framework::aptos_account::create_account(copy user_addr);
        let coin = coin::mint<AptosCoin>(100, &mint);
        coin::deposit(copy user_addr, coin);

        // user deposit the 100 coins into the vault
        let deposit_coin = coin::withdraw<AptosCoin>(&user, 100);
        deposit_vault<AptosCoin, AptosCoin>(&user, deposit_coin);

        // user withdraw his coins from the vault
        instant_withdraw_vault<AptosCoin, AptosCoin>(&user, 100);

        // assert vault is empty
        assert!(vault_balance<AptosCoin, AptosCoin>() == 0, E_VAULT_BALANCE_INCORRECT);

        // assert user balance is 100 coins
        assert!(get_user_balance(&user) == 100, E_VAULT_BALANCE_INCORRECT);

        coin::destroy_burn_cap(burn);
        coin::destroy_mint_cap(mint);
    }

    // test standard withdraw vault
    #[test(titusvaults = @0xa2bf272177d0723a90cb462bb087309e84554245934445af0da21132ba798b59, user = @0x2)]
    // expected failure because of timing restriction
    #[expected_failure]
    fun test_standard_withdraw_vault(titusvaults: &signer, user: signer) acquires RoundState, Vault, VaultMap {
        setup();

        // Initialize RoundState
        initialize_round_state(titusvaults);

        // create vault
        create_vault<AptosCoin, AptosCoin>(titusvaults);

        // add 100 coins to the user
        let user_addr = signer::address_of(&user);
        let (burn, mint) = aptos_framework::aptos_coin::initialize_for_test(&account::create_signer_for_test(@0x1));
        aptos_framework::aptos_account::create_account(copy user_addr);
        let coin = coin::mint<AptosCoin>(100, &mint);
        coin::deposit(copy user_addr, coin);

        // user deposit the 100 coins into the vault
        let deposit_coin = coin::withdraw<AptosCoin>(&user, 100);
        deposit_vault<AptosCoin, AptosCoin>(&user, deposit_coin);

        // user withdraw his coins from the vault
        standard_withdraw_vault<AptosCoin, AptosCoin>(&user, 100);

        // assert vault is empty
        assert!(vault_balance<AptosCoin, AptosCoin>() == 0, E_VAULT_BALANCE_INCORRECT);

        // assert user balance is 100 coins
        assert!(get_user_balance(&user) == 100, E_VAULT_BALANCE_INCORRECT);

        coin::destroy_burn_cap(burn);
        coin::destroy_mint_cap(mint);
    }
}
