module dropspace::CandyMachine {
    use std::vector;
    use std::string;
    use std::signer::{Self};
    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::coin::MintCapability;
    use dropspace::NFTForSale::{Self, NFTForSale};

    struct CandyMachine has key {
        nft_sales: vector<address>, // Addresses of NFTSale contracts
    }

    struct ResourceInfo has key {
        source: address,
        resource_cap: account::SignerCapability
    }

    public fun init_candy_machine(account: &signer) {
        move_to(account, CandyMachine {
            nft_sales: vector::empty(),
        });
    }

    public fun create_nft_sale(
        account: &signer,
        total_supply: u64,
        max_nfts_per_tx: u64,
        price_per_nft: u64,
        sale_start: u64,
        base_uri: vector<u8>,
        dev_wallet: address,
        owner_wallet: address,
        seeds: vector<u8> // Unique seed for each NFT sale
    ) acquires CandyMachine {
        let (resource, resource_cap) = account::create_resource_account(account, seeds);
        move_to(&resource, ResourceInfo { source: signer::address_of(account), resource_cap });
        
        NFTForSale::init_nft_sale(
            &resource,
            total_supply,
            max_nfts_per_tx,
            price_per_nft,
            sale_start,
            base_uri,
            dev_wallet,
            owner_wallet
        );

        let candy_machine = borrow_global_mut<CandyMachine>(signer::address_of(account));
        vector::push_back(&mut candy_machine.nft_sales, signer::address_of(&resource));
    }

    public fun get_nft_sales(account: address): vector<address> acquires CandyMachine {
        let candy_machine = borrow_global<CandyMachine>(account);
        candy_machine.nft_sales
    }

    // Tests 

    // Test initialization of the CandyMachine
    #[test_only]
    public fun test_init_candy_machine(account: &signer) {
        init_candy_machine(account);
        let candy_machine = borrow_global<CandyMachine>(signer::address_of(account));
        assert!(vector::length(&candy_machine.nft_sales) == 0, 0, b"CandyMachine should be initialized with empty sales vector");
    }

    // Test creating an NFT sale
    #[test_only]
    public fun test_create_nft_sale(account: &signer, mint_cap: &MintCapability) {
        let seeds = vec!(240, 159, 146, 150);
        let dev_wallet = @0x1;
        let owner_wallet = @0x2;

        init_candy_machine(account);
        create_nft_sale(account, 100, 5, 1000, 0, b"https://base.uri", dev_wallet, owner_wallet, seeds);

        let candy_machine = borrow_global<CandyMachine>(signer::address_of(account));
        assert!(vector::length(&candy_machine.nft_sales) == 1, 1, b"One NFT sale should have been created");
        
        let nft_sale_address = *vector::borrow(&candy_machine.nft_sales, 0);
        let nft_sale = borrow_global<NFTForSale>(nft_sale_address);
        assert!(nft_sale.total_supply == 100, 2, b"Total supply should be 100");
        assert!(nft_sale.max_nfts_per_tx == 5, 3, b"Max NFTs per tx should be 5");
        assert!(nft_sale.price_per_nft == 1000, 4, b"Price per NFT should be 1000");
    }
}
