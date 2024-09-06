module titusvaults::Vault {
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::event;
    use std::signer::address_of;
    use std::vector;
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

    struct RoundState has key, store {
        current_round_id: u64,
        shares: SmartTable<address, u64>,
        strike_price: u64,
        premium_price: u64,
        round_start_time: u64,
        deposit_start_time: u64,
        option_creation_time: u64,
        exercise_time: u64,
        close_timestamp: u64,
        total_amount_deposited: u64,
        total_premium_collected: u64,
        timestamps_set: bool,
        is_options_minted: bool,
    }

    struct Vault<phantom VaultT, phantom AssetT> has key {
        coin_store: Coin<AssetT>,
        creation_time: u64,
        creation_round: u64,
        total_shares: u64
    }

    struct VaultMap has key {
        deposits: SmartTable<address, u64>,
        rounds: vector<RoundState>,
        total_rounds: u64
    }

    struct WithdrawParams has key {
        round_id: u64,
        shares_to_burn: u64
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

    #[event]
    struct MintOptionsEvent has drop, store {
        round_id: u64,
        amount: u64,
        strike_price: u64,
        premium_price: u64,
    }

    // init round state
    public entry fun initialize_round_state(_host: &signer) {
        move_to(_host, RoundState {
            current_round_id: 1,
            shares: smart_table::new(),
            strike_price: 0,
            premium_price: 0,
            round_start_time: 0,
            deposit_start_time: 0,
            option_creation_time: 0,
            exercise_time: 0,
            close_timestamp: 0,
            total_amount_deposited: 0,
            total_premium_collected: 0,
            timestamps_set: false,
            is_options_minted: false
        });
    }
    
    // keeper functions
    public fun update_round_from_keeper(_host: &signer) acquires RoundState, VaultMap {
        let host_addr = signer::address_of(_host);
        let round_state = borrow_global_mut<RoundState>(@titusvaults);
        let vault_map = borrow_global_mut<VaultMap>(@titusvaults);

        let current_time = timestamp::now_microseconds();
        let new_round = round_state.current_round_id + 1;

        // Create a new RoundState for the new round (e.g., Round ID 2)
        let new_round = RoundState {
            current_round_id: new_round,
            shares: smart_table::new(),
            strike_price: round_state.strike_price,
            premium_price: round_state.premium_price,
            round_start_time: current_time,
            deposit_start_time: current_time,
            option_creation_time: current_time + DEPOSIT_PHASE_DURATION,
            exercise_time: current_time + DEPOSIT_PHASE_DURATION + OPTION_EXPIRY_DURATION,
            close_timestamp: current_time + DEPOSIT_PHASE_DURATION + OPTION_EXPIRY_DURATION + EXERCISE_BUFFER,
            total_amount_deposited: round_state.total_amount_deposited,
            total_premium_collected: round_state.total_premium_collected,
            timestamps_set: true,
            is_options_minted: round_state.is_options_minted
        };

        // Add the new RoundState to the rounds vector
        vector::push_back(&mut vault_map.rounds, new_round);

        // Update the total number of rounds
        vault_map.total_rounds = vault_map.total_rounds + 1;

        // round update event
        let update_event = RoundUpdatedEvent {
            new_round_id: round_state.current_round_id,
        };
        event::emit(update_event);
    }

    /// to create new vaults for Nth round
    public fun create_vault<VaultT, AssetT>(_host: &signer) acquires RoundState {
        let host_addr = address_of(_host);
        assert!(host_addr == @titusvaults, E_NOT_AUTHORIZED);

        let current_round = borrow_global<RoundState>(@titusvaults);
        if (!exists<VaultMap>(host_addr)) {
            move_to(_host, VaultMap {
                deposits: smart_table::new(),
                rounds: vector::empty<RoundState>(),
                total_rounds: 0
            });
            move_to(_host, Vault<VaultT, AssetT> {
                coin_store: coin::zero(),
                creation_time: timestamp::now_microseconds(),
                creation_round: current_round.current_round_id,
                total_shares: 0
            });
        };
    }

    // deposit vault
    public (friend) fun deposit_vault<VaultT, AssetT>( account: &signer, _coin: Coin<AssetT>) acquires Vault, VaultMap, RoundState {
        let user_addr = address_of(account);
        let vault = borrow_global_mut<Vault<VaultT, AssetT>>(@titusvaults);
        let vault_map = borrow_global_mut<VaultMap>(@titusvaults);
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
        };

        // update total deposit amount in the round state
        round_state.total_amount_deposited = round_state.total_amount_deposited + coin_value;

        // update vault total shares
        vault.total_shares = vault.total_shares + shares_to_mint;

        // merge deposited coins into the vault coin store
        coin::merge(&mut vault.coin_store, _coin);

        // deposit vault event
        let deposit_vault_event = DepositVaultEvent {
            depositor: user_addr,
            amount: coin_value,
            shares_minted: shares_to_mint,
            round: round_state.current_round_id
        };
        event::emit(deposit_vault_event);
    }

    // instant withdraw vault
    public (friend) fun instant_withdraw_vault<VaultT, AssetT>(account: &signer, amount: u64) acquires RoundState, Vault, VaultMap {
        let user_addr = address_of(account);

        let round_state = borrow_global_mut<RoundState>(@titusvaults);
        let vault = borrow_global_mut<Vault<VaultT, AssetT>>(@titusvaults);
        let vault_map = borrow_global_mut<VaultMap>(@titusvaults);
        let user_shares = *smart_table::borrow(&round_state.shares, user_addr);

        // assert we are during the deposit phase
        let current_time = timestamp::now_microseconds();
        let deposit_end_time = round_state.round_start_time + DEPOSIT_PHASE_DURATION;
        assert!(current_time <= deposit_end_time, E_NOT_DEPOSIT_PHASE);

        let current_deposit = *smart_table::borrow(&mut vault_map.deposits, user_addr);
        assert!(round_state.current_round_id == vault.creation_round, E_NOT_INSTANT_WITHDRAWAL);
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

        // update total deposit amount in the round state
        round_state.total_amount_deposited = round_state.total_amount_deposited - amount;

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

    // standard withdraw vault
    public (friend) fun standard_withdraw_vault<VaultT, AssetT>(account: &signer,  amount: u64) acquires RoundState, Vault, VaultMap {
        let user_addr = address_of(account);

        let round_state = borrow_global_mut<RoundState>(@titusvaults);
        let vault = borrow_global_mut<Vault<VaultT, AssetT>>(@titusvaults);
        let vault_map = borrow_global_mut<VaultMap>(@titusvaults);
        let user_shares = *smart_table::borrow(&round_state.shares, user_addr);

        let current_deposit = *smart_table::borrow(&mut vault_map.deposits, user_addr);

        // assert that standard withdrawal can only occur after the execution phase
        assert!(round_state.current_round_id >= vault.creation_round + 2, E_NOT_STANDARD_WITHDRAWAL);
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

        // update total deposit amount in the round state
        round_state.total_amount_deposited = round_state.total_amount_deposited - amount;

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

        // strike price updated event
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

        // premium price updated event
        let premium_price_updated_event = PremiumPriceUpdatedEvent {
            round_id: state.current_round_id,
            premium_price: new_premium_price
        };
        event::emit(premium_price_updated_event);
    }

    public (friend) fun executeRound<VaultT, AssetT>(_host: &signer, round_id: u64) acquires RoundState, VaultMap, Vault {

        let vault_map = borrow_global_mut<VaultMap>(@titusvaults);
        
        {
            let state = borrow_global_mut<RoundState>(@titusvaults);
            let current_round_id = state.current_round_id;
            // exercise the previous round
            let prev_round_id = current_round_id - 1;
            exerciseRound(_host, prev_round_id);
        };

        {
            let state = borrow_global_mut<RoundState>(@titusvaults);
            // mint options for the current round
            mintOptionsForRound<VaultT, AssetT>(_host, state.current_round_id);
        };

        {
            let state = borrow_global_mut<RoundState>(@titusvaults);
            // increment the current round ID
            state.current_round_id = state.current_round_id + 1;
            vault_map.total_rounds = vault_map.total_rounds + 1;

            // start deposit for the new round
            startDepositForRound(_host, state.current_round_id);
        }

    }
    
    // exercise round
    public (friend) fun exerciseRound(_host: &signer, round_id: u64) {
        let host_addr = address_of(_host);
        assert!(host_addr == @titusvaults, E_NOT_AUTHORIZED);
        // ....
    }

    // mint option for the round
    public (friend) fun mintOptionsForRound<VaultT, AssetT>(_host: &signer, round_id: u64) acquires RoundState, Vault {
        let host_addr = address_of(_host);
        assert!(host_addr == @titusvaults, E_NOT_AUTHORIZED);

        let state = borrow_global_mut<RoundState>(@titusvaults);
        let vault = borrow_global_mut<Vault<VaultT, AssetT>>(@titusvaults);

        // assert the round ID is valid and the options have not already been minted
        assert!(round_id == state.current_round_id, E_INVALID_OPERATION);
        assert!(!state.is_options_minted, E_INVALID_OPERATION);

        // assert that the asset deposited in the round is not 0
        assert!(state.total_amount_deposited > 0, E_INVALID_OPERATION);

        // assert that the round is in the active phase (after the deposit phase)
        let current_time = timestamp::now_microseconds();
        let active_phase_start_time = state.deposit_start_time + DEPOSIT_PHASE_DURATION;
        assert!(current_time >= active_phase_start_time, E_INVALID_OPERATION);

        // assert that the strike price and premium set on the vault are not older than 1 minute
        let strike_premium_validity_time = state.round_start_time + 60000000; // + 1 minute in microseconds
        assert!(current_time <= strike_premium_validity_time, E_INVALID_OPERATION);

        // mint the options using the underlying asset
        //----
        // mechanism to mint options....
        //----

        // mark the options as minted
        state.is_options_minted = true;

        // minting options event
        let mint_options_event = MintOptionsEvent {
            round_id: state.current_round_id,
            amount: state.total_amount_deposited,
            strike_price: state.strike_price,
            premium_price: state.premium_price,
        };
        event::emit(mint_options_event);
    }

    // start deposit for the round
    public (friend) fun startDepositForRound(_host: &signer, round_id: u64) acquires RoundState {
        let host_addr = address_of(_host);
        assert!(host_addr == @titusvaults, E_NOT_AUTHORIZED);

        let state = borrow_global_mut<RoundState>(@titusvaults);

        // assert the round ID is valid
        assert!(round_id == state.current_round_id, E_INVALID_OPERATION);

        // initialize the round state
        let current_time = timestamp::now_microseconds();
        let round_start_time = current_time;
        let active_phase_end_time = round_start_time + DEPOSIT_PHASE_DURATION;

    }  


    // --- views functions ---
    #[view]
    public fun current_round(): u64 acquires RoundState {
        let current_round = borrow_global<RoundState>(@titusvaults);
        return current_round.current_round_id
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
    #[test(titusvaults = @titusvaults, user = @0x2)]
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
    #[test(titusvaults = @titusvaults, user = @0x2)]
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
    #[test(titusvaults = @titusvaults, user = @0x2)]
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
    #[test(titusvaults = @titusvaults, user = @0x2)]
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
