module titusvaults::Vault {
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::aptos_coin::AptosCoin;
    use std::signer;
    use std::smart_table::{Self, SmartTable};

    struct Vault <phantom CollateralType> has key {
        balance: SmartTable<address, DepositBalance<CollateralType>>,
    }

    struct DepositBalance<phantom CollateralType> has store {
        balance: Coin<CollateralType>,
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