module Vault::main {
    use aptos_framework::coin::{self, Coin};
    use aptos_framework::aptos_coin::AptosCoin;
    use std::signer;

    struct VaultBalances has key {
        balance: Coin<AptosCoin>,
    }

    public fun create_vault(account: &signer) {
        let initial_balance = coin::zero<AptosCoin>();
        move_to(account, VaultBalances { balance: initial_balance });
    }

    public fun deposit(account: &signer, amount: u64) acquires Vault {
        let coin = coin::withdraw<AptosCoin>(account, amount);
        borrow_global_mut<Vault>(signer::address_of(account)).balance.value = borrow_global_mut<Vault>(signer::address_of(account)).balance.value + coin.value;
    }

    // Helper function to retrieve the balance of the vault for a given account
    public fun get_balance(account: address): u64 acquires Vault {
        borrow_global<Vault>(account).balance.value
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