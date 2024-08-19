module SolicyAdminAddress::SolicyVault {

  use std::signer;
  use std::error;
  use aptos_framework::coin;
  use aptos_framework::coin::Coin;

  
  const EAPP_NOT_INITIALIZED: u64 = 0;
  const EVAULT_NOT_EXISTS: u64 = 1;
  const EINVALID_BALANCE: u64 = 2;
  const EINVALID_VALUE: u64 = 3;
  const EINVALID_DEDICATED_INITIALIZER: u64 = 4;
  const EINVALID_ADMIN: u64 = 5;
  const EINVALID_COIN: u64 = 6;
  const EAPP_IS_PAUSED: u64 = 7;
  
  
  // Struct for Admin Address and Pause Status(0/1)
  struct AppInfo has key {
    admin_addr: address,
    is_paused: u8,
  }

  struct VaultInfo<phantom CoinType> has key {
    coin: Coin<CoinType>,
  }

// Initializer Function
  public entry fun initialize_app(initializer: &signer, admin_addr: address) {
    let initializer_addr = signer::address_of(initializer);
    assert!(initializer_addr == @SolicyAdminAddress, error::permission_denied(EINVALID_DEDICATED_INITIALIZER));
    move_to<AppInfo>(initializer, AppInfo {
        admin_addr,
        is_paused: 0,
    });
  }

  public entry fun deposit<CoinType>(account: &signer, amount: u64) acquires AppInfo, VaultInfo {

    let app_addr = @SolicyAdminAddress;
    assert!(exists<AppInfo>(app_addr), error::not_found(EAPP_NOT_INITIALIZED));

    let account_addr = signer::address_of(account);
    let app_info = borrow_global_mut<AppInfo>(app_addr);
    assert!(app_info.is_paused == 0, error::permission_denied(EAPP_IS_PAUSED));

    // withdraw coin from account
    let coin: Coin<CoinType> = coin::withdraw(account, amount);
    if (!exists<VaultInfo<CoinType>>(account_addr)) {
      move_to<VaultInfo<CoinType>>(account, VaultInfo<CoinType> {
        coin
      });
      if (!coin::is_account_registered<CoinType>(account_addr)) {
        coin::register<CoinType>(account);
      }
    } else {
      // if already deposited, then update vault_info
      let vault_info = borrow_global_mut<VaultInfo<CoinType>>(account_addr);
      coin::merge<CoinType>(&mut vault_info.coin, coin);
    };
  }

  public entry fun withdraw<CoinType>(account: &signer, amount: u64) acquires VaultInfo, AppInfo {
    
    let account_addr = signer::address_of(account);
    let app_addr = @SolicyAdminAddress;
    // check if app exists
    assert!(exists<AppInfo>(app_addr), error::not_found(EAPP_NOT_INITIALIZED));
    assert!(exists<VaultInfo<CoinType>>(account_addr), error::not_found(EVAULT_NOT_EXISTS));

    // extract coin in vault info and deposit to user's account
    let vault_info = borrow_global_mut<VaultInfo<CoinType>>(account_addr);
    let withdraw_coin = coin::extract<CoinType>(&mut vault_info.coin, amount);
    coin::deposit<CoinType>(account_addr, withdraw_coin);
    
    let app_info = borrow_global_mut<AppInfo>(app_addr); 
    assert!(app_info.is_paused == 0, error::permission_denied(EAPP_IS_PAUSED));
  }

  public entry fun pause(account: &signer) acquires AppInfo {
    let app_addr = @SolicyAdminAddress;
    assert!(exists<AppInfo>(app_addr), error::not_found(EAPP_NOT_INITIALIZED));

    let app_info = borrow_global_mut<AppInfo>(app_addr);

    // check if account is admin
    let account_addr = signer::address_of(account);
    assert!(app_info.admin_addr == account_addr, error::permission_denied(EINVALID_ADMIN));
    
    // resume the app
    app_info.is_paused = 1;
  }

  public entry fun unpause(account: &signer) acquires AppInfo {
    let app_addr = @SolicyAdminAddress;
    // check if app exists
    assert!(exists<AppInfo>(app_addr), error::not_found(EAPP_NOT_INITIALIZED));
    let app_info = borrow_global_mut<AppInfo>(app_addr);
    // check if account is admin
    let account_addr = signer::address_of(account);
    assert!(app_info.admin_addr == account_addr, error::permission_denied(EINVALID_ADMIN));
    app_info.is_paused = 0;

  }
  
}
