module titusvaults::Vault {
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::aptos_coin::AptosCoin;
    use std::signer;
    use std::account;
    use std::smart_table::{Self, SmartTable};

    const E_INVALID_OPERATION: u64 = 69;


    struct Vault <phantom CollateralType> has key {
        deposits: SmartTable<address, DepositBalance<CollateralType>>,
    }

    struct DepositBalance<phantom CollateralType> has store {
        balance: Coin<CollateralType>,
    }

    public fun create_vault <CollateralType>(account: &signer) {
        //TODO: ensure the account that is calling create_vault is authorized to do so
        // we'll have a vault per strategy, with differing underlying assets, strike prices etc
        // we also have to persist &signer's address somewhere for use in deposit/withdraw
        let init_deposits = smart_table::new<address, DepositBalance<CollateralType>>();
        move_to(account, Vault { deposits: init_deposits });
    }

    // TODO: this accepts Coin<CollateralType> and joins it to the deposit balance
    // but we may want to store balances in global storage instead of the Coins
    
    public fun deposit<CollateralType>(account: &signer, amount: Coin<CollateralType>, vault_addr: address) acquires Vault {
        let callee_address = signer::address_of(account);
        let vault = borrow_global_mut<Vault<CollateralType>>(vault_addr);
        // check first if the callee of this function already exists in our vault's deposits
        if (smart_table::contains(&vault.deposits, callee_address)) {
            let curr_deposit = smart_table::borrow_mut<address, DepositBalance<CollateralType>>(&mut vault.deposits, callee_address);
            coin::merge(&mut curr_deposit.balance, amount);
        } else {
            // we create the deposit for the user in our map
            smart_table::add<address, DepositBalance<CollateralType>>(&mut vault.deposits, callee_address, DepositBalance{balance: amount});
        }
    }
    
    // TODO: this accepts Coin<CollateralType> and joins it to the deposit balance
    // but we may want to store balances in global storage instead of the Coins
    // this function signature is inconsistent/different that deposit in that we accept amount as a u64

    // Note that we accept the vault_addr as an input_param for now, this probably will need to change, but is a "placeholder" for now
    public fun withdraw<CollateralType>(account: &signer, amount: u64, vault_addr: address) acquires Vault {
        let callee_address = signer::address_of(account);
        let vault = borrow_global_mut<Vault<CollateralType>>(vault_addr);
        // check first if the callee of this function already exists in our vault's deposits
        // there is no real else case here -- we could throw an error saying the user doesn't have an existing deposit, and handle it on the frontend
        
        if (smart_table::contains(&vault.deposits, callee_address)) {
            assert!(true, E_INVALID_OPERATION)
        };
        let curr_deposit = smart_table::borrow_mut<address, DepositBalance<CollateralType>>(&mut vault.deposits, callee_address);
        let withdrew_coins = coin::extract(&mut curr_deposit.balance, amount);
        coin::deposit(callee_address, withdrew_coins);
    }


    #[test]
fun test_deposit() {
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;

    // Set up the test environment
    let account = signer::new_signer(0x1);

    // Publish the AptosCoin and Vault resources
    coin::initialize<AptosCoin>(&account, 100_000_000);
    create_vault(&account);

    // Deposit some AptosCoin into the vault
    deposit(&account, 10_000);

    // Check the balance in the vault
    let balance = get_balance(signer::address_of(&account));
    assert!(balance == 10_000, 42);
}
}