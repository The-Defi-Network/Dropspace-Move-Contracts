module dropspace::CandyMachine {
    use std::vector;
    use std::signer::{Self};
    use std::string::{Self, String};
    use aptos_framework::account;
    use dropspace::NFTForSale::{Self};

    struct CandyMachine has key {
        nft_sales: vector<address>, // Addresses of NFTSale contracts
    }

    struct ResourceInfo has key {
        source: address,
        resource_cap: account::SignerCapability
    }

    public fun init_candy_machine(account: &signer) {
        let candy_machine_data = CandyMachine {
            nft_sales: vector::empty(),
        };
        move_to(account, candy_machine_data);
    }

    public entry fun create_nft_sale(
        account: &signer,
        name: String,
        ticker: String,
        mint_per_tx: u64,
        mint_price: u64,
        mint_fee: u64,
        supply_limit: u64,
        withdraw_wallet: address,
        dev_wallet: address,
        sale_time: u64,
        base_uri: String,
    ) acquires CandyMachine {
        let seeds = vector<u8>[ 240, 159, 146, 150];

        init_candy_machine(account);
        let (resource, resource_cap) = account::create_resource_account(account, seeds);
        move_to(&resource, ResourceInfo { source: signer::address_of(account), resource_cap });
        
        NFTForSale::init_nft_sale(
            account,
            name, 
            ticker,
            mint_per_tx,
            mint_price,
            mint_fee,
            supply_limit,
            withdraw_wallet,
            dev_wallet,
            sale_time,
            base_uri,
        );

        let candy_machine = borrow_global_mut<CandyMachine>(signer::address_of(account));
        vector::push_back(&mut candy_machine.nft_sales, signer::address_of(&resource));
    }

    #[view]
    public fun get_nft_sales(account: &signer): vector<address> acquires CandyMachine {
        let candy_machine = borrow_global<CandyMachine>(signer::address_of(account));
        candy_machine.nft_sales
    }

    // Tests 

    // Test initialization of the CandyMachine
    #[test(account = @0x1)]
    public fun test_init_candy_machine(account: &signer) acquires CandyMachine {
        init_candy_machine(account);
        let candy_machine = borrow_global_mut<CandyMachine>(signer::address_of(account));
        assert!(vector::length(&candy_machine.nft_sales) == 0, 0);
    }

    // Test creating an NFT sale
    #[test(account = @0x1)]
    public fun test_create_nft_sale(account: &signer) acquires CandyMachine {

     //   init_candy_machine(account);
        create_nft_sale(account, string::utf8(b"test_name"), string::utf8(b"test_ticker"), 10, 10, 1, 100, @0x1, @0x111, 0, string::utf8(b"test_uri"));

        let candy_machine = borrow_global_mut<CandyMachine>(signer::address_of(account));
        assert!(vector::length(&candy_machine.nft_sales) == 1, 0);
        let _nft_sale_address = *vector::borrow(&candy_machine.nft_sales, 0);
    }
}
