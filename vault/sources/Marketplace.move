module titusvaults::Marketplace {
    use std::vector;
    use std::signer::address_of;

    // --- structs ---
    struct Listing has key, store {
        option_contract_id: u64,
        price: u64,
        seller: address,
        is_sold: bool
    }

    struct ListingParams has key {
        option_contract_id: u64,
        price: u64
    }

    struct Listings has key {
        listings: vector<Listing>,
    }

    // --- functions ---

    // init listing
    public entry fun initialize_round_state(_host: &signer) {
        let host_addr = address_of(_host);
        move_to(_host, Listing {
            option_contract_id: 1,
            price: 0,
            seller: host_addr,
            is_sold: false
        });
    }

    public (friend) fun listOptions(_host: &signer) {

    }
    
}