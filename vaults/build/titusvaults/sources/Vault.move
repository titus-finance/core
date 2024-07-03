module titusvaults::Vault {
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::aptos_coin::AptosCoin;
    use std::signer;
    use std::smart_table::{Self, SmartTable};

    struct Vault <phantom CollateralType> has key {
        deposits: SmartTable<address, DepositBalance<CollateralType>>,
    }

    struct DepositBalance<phantom CollateralType> has store {
        balance: Coin<CollateralType>,
    }

    public fun create_vault <CollateralType>(account: &signer) {
        //TODO: ensure the account that is calling create_vault is authorized to do so
        // we'll have a vault per strategy, with differing underlying assets, strike prices etc
        let init_deposits = smart_table::new<address, DepositBalance<CollateralType>>();
        move_to(account, Vault { deposits: init_deposits });
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